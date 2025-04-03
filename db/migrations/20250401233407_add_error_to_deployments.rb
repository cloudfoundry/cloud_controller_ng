Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :error, String, null: true, default: nil, size: 255
    end
  end
end
