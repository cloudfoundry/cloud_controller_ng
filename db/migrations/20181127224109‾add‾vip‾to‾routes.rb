Sequel.migration do
  change do
    alter_table :routes do
      add_column :vip_offset, Integer, null: true, default: nil
      add_index :vip_offset, unique: true, name: :routes_vip_offset_index
    end
  end
end
