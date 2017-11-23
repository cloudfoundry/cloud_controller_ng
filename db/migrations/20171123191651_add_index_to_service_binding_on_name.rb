Sequel.migration do
  change do
    alter_table :service_bindings do
      add_index :name, name: :service_bindings_name_index
    end
  end
end
