Sequel.migration do
  change do
    create_table :app_usage_consumers do |_t|
      VCAP::Migration.common(self)
      String :consumer_guid, null: false, size: 255
      String :last_processed_guid, null: false, size: 255
    end
  end
end
