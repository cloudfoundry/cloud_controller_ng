Sequel.migration do
  change do
    alter_table :app_security_groups do
      add_index [:name], unique: true, name: 'asgs_name'
    end
  end
end
