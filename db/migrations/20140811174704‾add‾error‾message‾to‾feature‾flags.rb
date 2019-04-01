Sequel.migration do
  change do
    add_column :feature_flags, :error_message, String, text: true, default: nil
  end
end
