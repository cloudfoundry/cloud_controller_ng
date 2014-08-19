Sequel.migration do
  change do
    create_table :env_groups do
      VCAP::Migration.common(self, :evg)

      String :name, :null => false
      String :environment_json, :default => '{}', :null => false

      index :name, :unique => true
    end
  end
end
