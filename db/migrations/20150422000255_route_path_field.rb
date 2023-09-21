Sequel.migration do
  change do
    alter_table :routes do
      add_column :path, 'varchar(255)', default: '', null: false
      drop_index %i[host domain_id]
      add_index %i[host domain_id path], unique: true
    end
  end
end
