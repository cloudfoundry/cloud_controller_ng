Sequel.migration do
  change do
    alter_table :services do
      add_column :purging, TrueClass, default: false, null: false
    end
  end
end
