Sequel.migration do
  change do
    add_column :spaces, :allow_ssh, TrueClass, default: true
  end
end
