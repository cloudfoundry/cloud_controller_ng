Sequel.migration do
  change do
    create_table :deployment_processes do
      VCAP::Migration.common(self)
      String :process_guid, size: 255
      String :process_type, size: 255
      String :deployment_guid, size: 255

      foreign_key [:deployment_guid], :deployments, key: :guid, name: :fk_deployment_processes_deployment_guid
      index [:deployment_guid], name: :deployment_processes_deployment_guid_index
    end
  end
end
