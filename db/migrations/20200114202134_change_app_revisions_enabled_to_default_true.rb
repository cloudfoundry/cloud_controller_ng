Sequel.migration do
  change do
    drop_column :apps, :revisions_enabled
    add_column :apps, :revisions_enabled, 'Boolean', default: true
  end
end
