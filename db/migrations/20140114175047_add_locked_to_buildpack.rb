Sequel.migration do
  change do
    add_column :buildpacks, :locked, 'Boolean', :default => false
  end
end
