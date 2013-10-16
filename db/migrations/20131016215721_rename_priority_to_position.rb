Sequel.migration do
  change do
    alter_table :buildpacks do
      rename_column :priority, :position
    end
  end
end
