Sequel.migration do
  up do
    drop_table?(:ar_delayed_jobs)

    create_table :delayed_jobs do
      VCAP::Migration.common(self, :dj)

      Integer :priority, default: 0
      Integer :attempts, default: 0
      String :handler, text: true
      String :last_error, text: true
      Time :run_at
      Time :locked_at
      Time :failed_at
      String :locked_by
      String :queue
      index %i[priority run_at], name: :dj
    end
  end

  down do
    raise 'This is a forward-only migration'
  end
end
