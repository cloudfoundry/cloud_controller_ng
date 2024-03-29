Sequel.migration do
  up do
    drop_table :tasks
  end

  down do
    create_table :tasks do
      VCAP::Migration.common(self)

      Integer :app_id, null: false
      String :salt
      String :secure_token

      index :app_id

      foreign_key [:app_id], :apps, name: :fk_tasks_app_id
    end

    run 'ALTER TABLE `tasks` CHANGE COLUMN `secure_token` `secure_token` TEXT' if self.class.name.match?(/mysql/i)
  end
end
