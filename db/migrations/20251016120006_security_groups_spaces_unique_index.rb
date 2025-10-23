Sequel.migration do
  up do
    transaction do
      # Remove duplicate entries if they exist
      duplicates = self[:security_groups_spaces].
                   select(:security_group_id, :space_id).
                   group(:security_group_id, :space_id).
                   having { count(:security_groups_spaces_pk) > 1 }

      duplicates.each do |dup|
        security_groups_spaces_pks_to_remove = self[:security_groups_spaces].
                                               where(security_group_id: dup[:security_group_id], space_id: dup[:space_id]).
                                               select(:security_groups_spaces_pk).
                                               order(:security_groups_spaces_pk).
                                               offset(1).
                                               map(:security_groups_spaces_pk)

        self[:security_groups_spaces].where(security_groups_spaces_pk: security_groups_spaces_pks_to_remove).delete
      end

      alter_table(:security_groups_spaces) do
        # Cannot add unique constraint concurrently as it requires a transaction
        # rubocop:disable Sequel/ConcurrentIndex
        add_index %i[security_group_id space_id], unique: true, name: :security_groups_spaces_ids unless @db.indexes(:security_groups_spaces).key?(:security_groups_spaces_ids)
        drop_index %i[security_group_id space_id], name: :sgs_spaces_ids if @db.indexes(:security_groups_spaces).key?(:sgs_spaces_ids)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    alter_table(:security_groups_spaces) do
      # rubocop:disable Sequel/ConcurrentIndex
      add_index %i[security_group_id space_id], name: :sgs_spaces_ids unless @db.indexes(:security_groups_spaces).key?(:sgs_spaces_ids)
      drop_index %i[security_group_id space_id], unique: true, name: :security_groups_spaces_ids if @db.indexes(:security_groups_spaces).key?(:security_groups_spaces_ids)
      # rubocop:enable Sequel/ConcurrentIndex
    end
  end
end
