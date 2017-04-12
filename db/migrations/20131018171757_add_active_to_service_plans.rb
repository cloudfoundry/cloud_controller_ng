Sequel.migration do
  change do
    alter_table :service_plans do
      add_column :active, TrueClass, default: true
    end
  end
end
