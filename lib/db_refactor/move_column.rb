module DbRefactor

  module MoveColumn

    # Migrate a single +column+ from +from_table+ to +to_table+, retaining the value.
    # If the referenced target object is not found, it will be created (using
    # the .create_'referenced' method).
    # Especially useful for refactoring :has_one associations
    #
    # Notice: automatically calls reset_column_information on the ActiveRecord types,
    # to make sure new objects or later migrations use the new table structure.
    def move_column column, from_table, to_table
      from_type = from_table.to_s.classify.constantize
      add_target_column(from_type, to_table, column)

      from_type.transaction do
        each_row(from_type, to_table) do |from_instance|
          value = from_instance[column]
          referenced = load_or_create_referenced(from_instance, to_table)

          referenced[column] = value
          referenced.save!
        end
      end

      remove_source_column(from_table, column)
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
      to_table.to_s.classify.constantize.reset_column_information
    end

    # Remove +column+ from the +from_table+
    def remove_source_column from_table, column
      remove_column from_table, column
      from_table.to_s.classify.constantize.reset_column_information
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

    # Yields all records from +from_type+, one at a time.  Loads +limit+ records
    # into memory at a time. To avoid the N+1 loading problem, the referenced objects are included when loading
    def each_row from_type, to_table, limit = 50
      rows = from_type.all(:order => 'id', :limit => limit,
        :include => reference_name(to_table))
      while rows.any?
        rows.each { |record| yield record }
        rows = from_type.all(:order => 'id', :limit => limit,
          :include => reference_name(to_table), :conditions => ["id > ?", rows.last.id])
      end
    end
  end
end