Sequel.migration do
  up do
    alter_table :service_brokers do
      drop_index :broker_url, name: :sb_broker_url_index
      add_index :broker_url, name: :sb_broker_url_index, unique: false
    end
  end

  down do
    alter_table :service_brokers do
      drop_index :broker_url, name: :sb_broker_url_index
      add_index :broker_url, name: :sb_broker_url_index, unique: true
    end
  end
end
