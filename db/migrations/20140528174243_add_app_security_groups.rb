Sequel.migration do
  change do
    create_table :app_security_groups do
      VCAP::Migration.common(self, "app_security_groups")
      String :name, null: false
      String :rules
    end
  end
end
