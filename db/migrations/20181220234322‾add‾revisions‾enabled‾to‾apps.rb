Sequel.migration do
  change do
    alter_table :apps do
      add_column :revisions_enabled, 'Boolean', default: false
    end
  end
end
