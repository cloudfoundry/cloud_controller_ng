Sequel.migration do
  change do
    add_column :builds, :error_id, String
  end
end
