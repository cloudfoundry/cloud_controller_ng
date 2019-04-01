Sequel.migration do
  change do
    create_table :packages do
      VCAP::Migration.common(self)
      String :space_guid
      index :space_guid
      String :type
      index :type
      String :package_hash
      String :state, null: false
      String :error, text: true
      String :url
    end
  end
end
