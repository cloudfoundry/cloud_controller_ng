Sequel.migration do
  change do
    alter_table :deployments do
      rename_column :webish_process_guid, :deploying_web_process_guid
    end
  end
end
