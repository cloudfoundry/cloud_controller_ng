Sequel.migration do
  change do
    create_table :buildpacks do
      VCAP::Migration.common(self)

      String :name, null: false
      String :key
      Integer :priority, null: false

      index :name, unique: true
    end
  end
end
