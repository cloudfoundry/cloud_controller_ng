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
      if Sequel::Model.db.database_type == :mssql
        String :error, size: :max
      else
        String :error, text: true
      end
      String :url
    end
  end
end
