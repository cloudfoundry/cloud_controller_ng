Sequel.migration do
  change do
    alter_table(:buildpacks) do
      add_column :enabled, TrueClass, default: true
    end
  end
end
