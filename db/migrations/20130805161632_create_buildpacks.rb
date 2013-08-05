Sequel.migration do
  change do
    create_table :buildpacks do
      VCAP::Migration.common(self)

      String :name, null: false, unique: true
      String :url, null: false
    end
  end
end
