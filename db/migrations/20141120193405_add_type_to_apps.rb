Sequel.migration do
  change do
    add_column :apps, :type, String, default: 'web'
  end
end
