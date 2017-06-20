Sequel.migration do
  change do
    alter_table :buildpacks do
      add_index :key, name: :buildpacks_key_index
    end
  end
end
