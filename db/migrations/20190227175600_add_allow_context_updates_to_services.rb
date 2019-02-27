Sequel.migration do
  change do
    alter_table :services do
      add_column :allow_context_updates, :boolean, default: false, null: false
    end
  end
end
