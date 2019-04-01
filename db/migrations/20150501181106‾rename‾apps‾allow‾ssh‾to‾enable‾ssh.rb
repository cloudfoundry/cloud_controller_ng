Sequel.migration do
  change do
    rename_column :apps, :allow_ssh, :enable_ssh
  end
end
