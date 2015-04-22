Sequel.migration do
  change do
    alter_table :routes do
      add_column :path, String, text: true, default: nil
    end
  end
end
