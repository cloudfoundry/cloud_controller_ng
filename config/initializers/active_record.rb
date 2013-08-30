require "active_record/base"
require "delayed_job_active_record"

module CCInitializers
  def self.active_record(_)
    # ActiveRecord uses a table named schema_migrations.  So does Sequel.
    # However, the schemas of those tables are different, and the only apparent way to
    # resolve the conflict here is to have ActiveRecord use a prefix to force a different table.
    ActiveRecord::Base.table_name_prefix = "ar_"
    Delayed::Job.set_delayed_job_table_name
  end
end