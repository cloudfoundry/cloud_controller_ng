Sequel.migration do
  change do
    create_table :request_counts do
      primary_key :id

      String :user_guid
      index :user_guid

      Integer :count, default: 0
    end
  end
end
