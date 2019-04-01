Sequel.migration do
  change do
    alter_table :services do
      add_column :bindings_retrievable, :boolean, default: false, null: false
      add_column :instances_retrievable, :boolean, default: false, null: false
    end
  end
end
