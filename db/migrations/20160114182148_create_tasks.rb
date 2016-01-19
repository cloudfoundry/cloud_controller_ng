Sequel.migration do
  change do
    create_table :tasks do
      VCAP::Migration.common(self)

      String :name, case_insensitive: true, null: false
      String :command, null: false
      String :state, null: false

      Integer :app_id, null: false
      foreign_key [:app_id], :apps_v3, name: :fk_tasks_app_id

      Integer :droplet_id, null: false
      foreign_key [:droplet_id], :v3_droplets, name: :fk_tasks_droplet_id

      if self.class.name.match /mysql/i
        table_name = tables.find { |t| t =~ /tasks/ }
        run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
      end
    end
  end
end
