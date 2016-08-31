Sequel.migration do
  up do
    collate_opts = {}
    if self.class.name.match(/mysql/i)
      collate_opts[:collate] = :utf8_bin
    end

    alter_table :isolation_segments do
      if self.class.name.match(/mysql/i)
        table_name = tables.find { |t| t =~ /isolation_segments/ }
        run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
      end
    end

    alter_table :spaces do
      add_column :isolation_segment_guid, String, collate_opts
      add_foreign_key [:isolation_segment_guid], :isolation_segments, key: :guid, name: :fk_spaces_isolation_segment_guid
    end
  end

  down do
    alter_table :spaces do
      drop_foreign_key :isolation_segment_guid
    end
  end
end
