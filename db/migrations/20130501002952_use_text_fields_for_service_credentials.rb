Sequel.migration do
  change do
    alter_table :service_instances do
      add_column :credentials_text, String, :text => true
    end
    
    run "update service_instances set credentials_text=credentials, credentials=null"
    
    alter_table :service_instances do
      drop_column :credentials
      rename_column :credentials_text, :credentials
    end

    alter_table :service_bindings do
      add_column :credentials_text, String, :text => true
    end
    
    run "update service_bindings set credentials_text=credentials, credentials=null"
    
    alter_table :service_bindings do
      drop_column :credentials
      rename_column :credentials_text, :credentials
    end
  end
end
