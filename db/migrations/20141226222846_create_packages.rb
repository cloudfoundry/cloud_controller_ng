Sequel.migration do
  change do
    create_table :packages do
      VCAP::Migration.common(self)
      String :app_guid
      index :app_guid
      String :type
      index :type
      String :package_hash
      String :state, default: 'PENDING', null: false
      String :error, text: true
    end
  end
end
