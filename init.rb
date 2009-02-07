config.after_initialize do
  ActiveRecord::Migration.send(:extend, DbRefactor::MoveColumn)
end