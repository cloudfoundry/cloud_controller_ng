Sequel.migration do
  change do
    alter_table :processes do
      add_column :health_check_invocation_timeout, :integer, null: true, default: nil
    end
  end
end
