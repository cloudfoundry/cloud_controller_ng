Sequel.migration do
  change do
    alter_table(:stacks) do
      add_column :state, String, null: false, default: 'ACTIVE', size: 255
    end
  end
end
