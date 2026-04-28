Sequel.migration do # rubocop:disable Metrics/BlockLength
  no_transaction # required for concurrently option on postgres

  up do
    transaction do
      duplicates = self[:security_groups].select(:name).
                   group(:name).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:security_groups].
                        where(name: dup[:name]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)
        self[:security_groups_spaces].where(security_group_id: ids_to_remove).delete
        self[:staging_security_groups_spaces].where(staging_security_group_id: ids_to_remove).delete
        self[:security_groups].where(id: ids_to_remove).delete
      end
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :security_groups, :name,
                  name: :security_groups_name_index,
                  unique: true,
                  concurrently: true,
                  if_not_exists: true
        drop_index :security_groups, nil,
                   name: :sg_name_index,
                   concurrently: true,
                   if_exists: true
      end
    else
      alter_table(:security_groups) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        add_index :name, name: :security_groups_name_index, unique: true unless @db.indexes(:security_groups).key?(:security_groups_name_index)
        drop_index :name, name: :sg_name_index if @db.indexes(:security_groups).key?(:sg_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :security_groups, :name,
                  name: :sg_name_index,
                  concurrently: true,
                  if_not_exists: true
        drop_index :security_groups, nil,
                   name: :security_groups_name_index,
                   concurrently: true,
                   if_exists: true
      end
    else
      alter_table(:security_groups) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        add_index :name, name: :sg_name_index unless @db.indexes(:security_groups).key?(:sg_name_index)
        drop_index :name, name: :security_groups_name_index if @db.indexes(:security_groups).key?(:security_groups_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
