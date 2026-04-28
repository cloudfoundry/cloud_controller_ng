Sequel.migration do
  no_transaction # required for concurrently option on postgres
  up do
    transaction do
      # Remove duplicate entries if they exist
      duplicates = self[:buildpacks].select(:name, :stack, :lifecycle).group(:name, :stack, :lifecycle).having { count(1) > 1 }

      duplicates.each do |dup|
        rows_to_remove = self[:buildpacks].where(name: dup[:name], stack: dup[:stack], lifecycle: dup[:lifecycle]).
                         select(:id, :guid).order(:id).offset(1).all

        guids_to_remove = rows_to_remove.map { |r| r[:guid] }
        ids_to_remove   = rows_to_remove.map { |r| r[:id] }

        self[:buildpack_annotations].where(resource_guid: guids_to_remove).delete
        self[:buildpack_labels].where(resource_guid: guids_to_remove).delete
        self[:buildpacks].where(id: ids_to_remove).delete
      end
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :buildpacks, nil,
                   name: :unique_name_and_stack,
                   concurrently: true,
                   if_exists: true
        add_index :buildpacks, %i[name stack lifecycle],
                  name: :buildpacks_name_stack_lifecycle_index,
                  unique: true,
                  concurrently: true,
                  if_not_exists: true
      end
    else
      alter_table(:buildpacks) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        drop_index %i[name stack], name: :unique_name_and_stack if @db.indexes(:buildpacks).key?(:unique_name_and_stack)
        unless @db.indexes(:buildpacks).key?(:buildpacks_name_stack_lifecycle_index)
          add_index %i[name stack lifecycle], unique: true,
                                              name: :buildpacks_name_stack_lifecycle_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :buildpacks, nil, name: :buildpacks_name_stack_lifecycle_index, concurrently: true, if_exists: true
        add_index :buildpacks, %i[name stack], name: :unique_name_and_stack, unique: true, concurrently: true, if_not_exists: true
      end
    else
      alter_table(:buildpacks) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        drop_index %i[name stack lifecycle], name: :buildpacks_name_stack_lifecycle_index if @db.indexes(:buildpacks).key?(:buildpacks_name_stack_lifecycle_index)
        add_index %i[name stack], unique: true, name: :unique_name_and_stack unless @db.indexes(:buildpacks).key?(:unique_name_and_stack)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
