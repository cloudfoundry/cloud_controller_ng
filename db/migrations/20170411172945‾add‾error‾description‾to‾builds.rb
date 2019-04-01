Sequel.migration do
  change do
    add_column :builds, :error_description, String
  end
end
