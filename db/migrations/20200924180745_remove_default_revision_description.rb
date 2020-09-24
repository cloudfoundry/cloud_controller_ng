Sequel.migration do
  change do
    set_column_default(:revisions, :description, nil)
  end
end
