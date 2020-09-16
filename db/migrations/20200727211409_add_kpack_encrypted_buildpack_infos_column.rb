require 'multi_json'

Sequel.migration do
  change do
    alter_table :kpack_lifecycle_data do
      add_column :buildpacks, String, size: 5000, default: MultiJson.dump([])
    end
  end
end
