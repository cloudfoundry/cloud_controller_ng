Sequel.migration do
  change do
    create_table :app_security_groups do
      VCAP::Migration.common(self, "asg")
      String :name, null: false
      String :rules, size: 2048
    end
  end
end
