Sequel.migration do
  up do
    alter_table :services do
      if @db.class.to_s.include? 'Mysql'
        drop_constraint :services_label_provider_index, type: :unique
      end
      drop_column :provider
      drop_column :url
      drop_column :version
    end
  end

  down do
    alter_table :services do
      add_column :provider, String, null: false, size: 255, case_insensitive: true
      add_column :url, String, null: false, size: 255
      add_column :version, String, null: false, size: 255
    end
  end
end
