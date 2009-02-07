config.after_initialize do
  ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, DbRefactor::MoveColumn)
end