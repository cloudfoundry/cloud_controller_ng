Sequel.migration do
  change do
    alter_table(:service_accounts) do
      add_column :description, String, size: 250, null: false, default: ''
    end
    create_table(:service_account_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_account_labels, :service_accounts)
    end
    create_table(:service_account_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_account_annotations, :service_accounts)
    end
    rename_column :service_account_annotations, :key, :key_name
  end
end
