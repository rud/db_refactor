module DbRefactor
  module MoveColumn
    # Notice: only if the module is explicitly included in a migration is anything changed
    def self.included(base)
      base.extend DbRefactor::MoveColumn
    end
  end
end