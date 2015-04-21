Sequel.migration do
  change do
    add_column :apps, :allow_ssh, TrueClass, default: false
  end
end
