Sequel.migration do
  change do
    alter_table :service_plans do
      add_column :public, :boolean, default: true
    end
  end
end
