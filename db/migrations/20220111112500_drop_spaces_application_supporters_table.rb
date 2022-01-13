Sequel.migration do
  change do
    # This table is superseded by spaces_supporters.
    drop_table?(:spaces_application_supporters)
  end
end
