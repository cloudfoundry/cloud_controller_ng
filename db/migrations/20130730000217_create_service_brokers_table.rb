Sequel.migration do
  change do
    create_table :service_brokers do
      VCAP::Migration.common(self, :sbrokers)
      String :name,        null: false
      String :broker_url, null: false
      String :token,       null: false

      index :name,        unique: true
      index :broker_url, unique: true
    end
  end
end
