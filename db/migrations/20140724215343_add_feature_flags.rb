Sequel.migration do
  change do
    create_table :feature_flags do
      VCAP::Migration.common(self, :feature_flag)

      String :name, null: false
      TrueClass :enabled, null: false

      index :name, unique: true
    end
  end
end
