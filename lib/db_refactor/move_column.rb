module DbRefactor

  module MoveColumn

    # How many rows to fetch at a time when iterating an entire table
    PAGING_LIMIT = 50

    # Migrate one ore more +columns+ from +from_table+ to +to_table+, retaining the values.
    # If the referenced target object is not found, it will be created (using
    # the .create_'referenced' method).
    # Especially useful for refactoring :has_one associations
    #
    # Notice: automatically calls reset_column_information on the ActiveRecord types,
    # to make sure new objects or later migrations use the new table structure.
    def move_column columns, from_table, to_table
      from_type = from_table.to_s.classify.constantize
      [columns].flatten.each do |column|
        add_target_column(from_type, to_table, column)
      end
      to_table.to_s.classify.constantize.reset_column_information

      from_type.transaction do
        each_row(from_type, reference_name(to_table)) do |from_instance|
          referenced = nil
          [columns].flatten.each do |column|
            value = from_instance[column]
            referenced = load_or_create_referenced(from_instance, to_table)
            referenced[column] = value
          end
          referenced.save!
        end
      end

      [columns].flatten.each do |column|
        remove_source_column(from_table, column)
      end
      from_table.to_s.classify.constantize.reset_column_information
    end

    private
    # Create a column in +to_table+ of the same type as +column+ in +from_type+
    def add_target_column from_type, to_table, column
      moving_column = from_type.new.column_for_attribute(column)

      attributes_hash = {}
      moving_column.instance_variables.each do |var|
        attributes_hash[var.gsub("@","").to_sym] = moving_column.instance_variable_get(var)
      end

      add_column to_table, column, moving_column.type, attributes_hash
    end

    # Remove +column+ from the +from_table+
    def remove_source_column from_table, column
      remove_column from_table, column
    end

    # Load the reference to the assocated table - will attempt to create it if it is missing
    def load_or_create_referenced from_instance, to_table
      referenced = from_instance.send(reference_name(to_table))
      if referenced.blank?
        referenced = from_instance.send("build_#{reference_name(to_table)}")
      end
      referenced
    end

    # Generate the name of the reference. A +to_table+ of :preferences becomes 'preference'
    def reference_name to_table
      to_table.to_s.singularize
    end

    # Yields all records from +from_type+, one at a time.  Loads +interval+ records
    # into memory at a time.
    # The N+1 loading problem can be avoided by using +include_reference+
    def each_row from_type, include_reference = nil, interval = PAGING_LIMIT
      fetch_options = {
        :order => 'id',
        :limit => interval
      }
      fetch_options[:include] = include_reference unless include_reference.blank?

      rows = from_type.all(fetch_options)
      while rows.any?
        rows.each { |record| yield record }
        fetch_options[:conditions] = ["id > ?", rows.last.id]
        rows = from_type.all(fetch_options)
      end
    end
    public :each_row
  end
end