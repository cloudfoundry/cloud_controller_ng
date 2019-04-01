Sequel.migration do
  change do
    alter_table(:apps) do
      add_column :admin_buildpack_id, Integer
    end
  end
end
