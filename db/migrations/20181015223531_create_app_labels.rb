Sequel.migration do
  change do
    create_table :app_labels do
      VCAP::Migration.common(self)
      String :app_guid, size: 255
      String :label_key, size: 511
      String :label_value, size: 255

      foreign_key [:app_guid], :apps, key: :guid, name: :fk_app_labels_app_guid
      index [:app_guid], name: :fk_app_labels_app_guid_index
      index [:label_key, :label_value], name: :app_labels_compound_index
    end
  end
end
