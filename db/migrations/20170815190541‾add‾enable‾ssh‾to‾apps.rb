Sequel.migration do
  change do
    add_column :apps, :enable_ssh, 'Boolean', null: true
  end
end
