Sequel.migration do
  change do
    create_table :isolation_segments do
      VCAP::Migration.common(self)
      String :name, null: false, case_insensitive: :true, unique: true
      index :name
    end
  end
end
