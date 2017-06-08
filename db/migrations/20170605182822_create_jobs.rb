Sequel.migration do
  change do
    create_table :jobs do
      VCAP::Migration.common(self)
      String :state
      String :operation
      String :resource_guid
      String :resource_type
    end
  end
end
