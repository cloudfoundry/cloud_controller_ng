require 'sequel'
require 'delayed_job'

module DelayedJobSequel
  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || :delayed_jobs
  end
end
