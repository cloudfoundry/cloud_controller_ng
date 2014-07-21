Sequel.migration do
  change do
    add_column :apps, :diego, TrueClass, :default => false
  end
end
