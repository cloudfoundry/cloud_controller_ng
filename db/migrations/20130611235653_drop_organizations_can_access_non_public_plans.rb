Sequel.migration do
  up do
    drop_column :organizations, :can_access_non_public_plans
  end

  down do
    alter_table :organizations do
      add_column :can_access_non_public_plans, :boolean, default: false, null: false
    end
  end
end
