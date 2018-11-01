Sequel.migration do
  up do
    # These tables were never present in a released capi-release so it is safe to drop them
    drop_table(:app_labels)
    create_table(:app_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :app_labels, :apps)
    end

    drop_table(:org_labels)
    create_table(:organization_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :organization_labels, :organizations)
    end

    drop_table(:space_labels)
    create_table(:space_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :space_labels, :spaces)
    end
  end

  down do
    # This migration cannot be reversed
  end
end
