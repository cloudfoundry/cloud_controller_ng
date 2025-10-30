Sequel.migration do
  up do
    transaction do
      # Clean up sidecar_process_types
      duplicates = self[:sidecar_process_types].
                   select(:sidecar_guid, :type).
                   group(:sidecar_guid, :type).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        pks_to_remove = self[:sidecar_process_types].
                        where(sidecar_guid: dup[:sidecar_guid], type: dup[:type]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)

        self[:sidecar_process_types].where(id: pks_to_remove).delete
      end

      alter_table(:sidecar_process_types) do
        unless @db.indexes(:sidecar_process_types).key?(:sidecar_process_types_sidecar_guid_type_index)
          add_unique_constraint %i[sidecar_guid type],
                                name: :sidecar_process_types_sidecar_guid_type_index
        end
      end
    end

    transaction do
      # Clean up revision_sidecar_process_types
      duplicates = self[:revision_sidecar_process_types].
                   select(:revision_sidecar_guid, :type).
                   group(:revision_sidecar_guid, :type).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        pks_to_remove = self[:revision_sidecar_process_types].
                        where(revision_sidecar_guid: dup[:revision_sidecar_guid], type: dup[:type]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)

        self[:revision_sidecar_process_types].where(id: pks_to_remove).delete
      end

      alter_table(:revision_sidecar_process_types) do
        unless @db.indexes(:revision_sidecar_process_types).key?(:revision_sidecar_process_types_revision_sidecar_guid_type_index)
          add_unique_constraint %i[revision_sidecar_guid type],
                                name: :revision_sidecar_process_types_revision_sidecar_guid_type_index
        end
      end
    end
  end

  down do
    alter_table(:sidecar_process_types) do
      drop_constraint(:sidecar_process_types_sidecar_guid_type_index, type: :unique) if @db.indexes(:sidecar_process_types).key?(:sidecar_process_types_sidecar_guid_type_index)
    end

    alter_table(:revision_sidecar_process_types) do
      if @db.indexes(:revision_sidecar_process_types).key?(:revision_sidecar_process_types_revision_sidecar_guid_type_index)
        drop_constraint(:revision_sidecar_process_types_revision_sidecar_guid_type_index,
                        type: :unique)
      end
    end
  end
end
