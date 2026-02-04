Sequel.migration do
  change do
    alter_table(:revisions) do
      add_column :description, String, text: true, default: 'N/A', null: false
    end
  end
end
