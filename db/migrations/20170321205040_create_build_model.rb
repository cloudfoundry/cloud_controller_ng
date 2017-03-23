Sequel.migration do
  change do
    create_table :builds do
      VCAP::Migration.common(self)
      String :state
    end

    alter_table :droplets do
      add_column :build_guid, String
      add_index :build_guid, name: :build_guid_index
    end
  end
end
