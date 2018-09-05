Sequel.migration do
  change do
    alter_table :deployments do
      add_column :original_web_process_instance_count, :integer, null: false
    end
  end
end
