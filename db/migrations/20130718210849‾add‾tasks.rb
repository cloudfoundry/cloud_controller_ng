Sequel.migration do
  change do
    create_table :tasks do
      VCAP::Migration.common(self)

      Integer :app_id, null: false

      index :app_id

      foreign_key [:app_id], :apps, name: :fk_tasks_app_id
    end
  end
end
