Sequel.migration do
  change do
    create_table(:user_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :user_labels, :users)
    end

    create_table(:user_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :user_annotations, :users)
    end
  end
end
