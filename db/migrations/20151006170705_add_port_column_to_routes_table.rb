Sequel.migration do
  change do
    alter_table :routes do
      add_column :port, Integer, null: false, default: 0
      drop_index [:host, :domain_id, :path]
      add_index [:host, :domain_id, :path, :port], unique: true
    end
  end
end
