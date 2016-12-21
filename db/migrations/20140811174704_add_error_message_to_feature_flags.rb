Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      add_column :feature_flags, :error_message, String, size: :max, default: nil
    else
      add_column :feature_flags, :error_message, String, text: true, default: nil
    end
  end
end
