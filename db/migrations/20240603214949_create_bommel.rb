Sequel.migration do
  change do
    create_table :bommel do
      String :b_guid, null: false, size: 255
      String :target_space_guid, null: false, size: 255
      primary_key %i[b_guid target_space_guid], name: :bommel_target_space_pk
    end
  end
end
