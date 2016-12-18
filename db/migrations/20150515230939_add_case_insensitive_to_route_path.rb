Sequel.migration do
  up do
    alter_table :routes do
      drop_index [:host, :domain_id, :path]
      set_column_type :path, String, default: '', null: false, case_insensitive: true
      add_index [:host, :domain_id, :path], unique: true
    end
  end

  down do
    alter_table :routes do
      set_column_type :path, 'varchar(255)', default: '', null: false
    end
  end
end
