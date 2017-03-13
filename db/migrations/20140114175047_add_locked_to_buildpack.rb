Sequel.migration do
  change do
    add_column :buildpacks, :locked, TrueClass, default: false
  end
end
