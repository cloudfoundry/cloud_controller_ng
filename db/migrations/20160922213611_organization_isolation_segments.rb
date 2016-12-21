Sequel.migration do
  up do
    create_table :organizations_isolation_segments do
      String :organization_guid, null: false
      String :isolation_segment_guid, null: false

      foreign_key [:organization_guid], :organizations, key: :guid, name: :fk_organization_guid
      foreign_key [:isolation_segment_guid], :isolation_segments, key: :guid, name: :fk_isolation_segments_guid
      primary_key [:organization_guid, :isolation_segment_guid], name: :organizations_isolation_segments_pk
    end

    collate_opts = {}
    if self.class.name =~ /mysql/i
      collate_opts[:collate] = :utf8_bin
    end

    alter_table :organizations do
      add_column :default_isolation_segment_guid, String, collate_opts
      if Sequel::Model.db.database_type == :mssql
        add_foreign_key [:guid, :default_isolation_segment_guid], :organizations_isolation_segments, name: 'organizations_isolation_segments_fk'
      else
        add_foreign_key [:guid, :default_isolation_segment_guid], :organizations_isolation_segments, name: 'organizations_isolation_segments_pk'
      end
    end
  end

  down do
    alter_table :organizations do
      if Sequel::Model.db.database_type == :mssql
        drop_foreign_key :organizations_isolation_segment_fk
      else
        drop_foreign_key :organizations_isolation_segment_pk
      end
    end

    drop_table :organizations_isolation_segments
  end
end
