Sequel.migration do
  change do
    create_table :v3_service_bindings do
      VCAP::Migration.common(self)

      String :credentials, text: true, null: false, size: 2048
      String :salt

      String :syslog_drain_url

      String :type, null: false

      Integer :app_id, null: false
      foreign_key [:app_id], :apps_v3, name: :fk_v3_service_bindings_app_id

      Integer :service_instance_id, null: false
      foreign_key [:service_instance_id], :service_instances, name: :fk_v3_service_bindings_service_instance_id

      index [:app_id, :service_instance_id], unique: true
    end
  end
end
