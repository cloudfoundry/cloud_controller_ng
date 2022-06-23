Sequel.migration do
  change do
    create_table :asg_timestamps do
      primary_key name: :id
      Timestamp :last_update
    end
  end
end
