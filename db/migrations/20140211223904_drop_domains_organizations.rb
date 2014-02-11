Sequel.migration do
  up do
    drop_table(:domains_organizations)
  end
end
