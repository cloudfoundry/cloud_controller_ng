Sequel.migration do
  change do
    alter_table :service_plans do
      add_column :active, 'Boolean', default: true
    end
  end
end
