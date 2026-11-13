Sequel.migration do
  no_transaction

  up do
    tables = [
      { table: :apps,     guid_column: :app_guid     },
      { table: :droplets, guid_column: :droplet_guid },
      { table: :builds,   guid_column: :build_guid   }
    ]
    batch_size = 1000

    tables.each do |t|
      table       = t[:table]
      guid_column = t[:guid_column]

      loop do
        guids = self[table].where(lifecycle_type: nil).limit(batch_size).select_map(:guid)
        break if guids.empty?

        guids_with_buildpack = self[:buildpack_lifecycle_data].where(guid_column => guids).select_map(guid_column)
        guids_with_cnb       = self[:cnb_lifecycle_data].where(guid_column => guids).select_map(guid_column) - guids_with_buildpack
        guids_docker         = guids - guids_with_buildpack - guids_with_cnb

        transaction do
          self[table].where(guid: guids_with_buildpack, lifecycle_type: nil).update(lifecycle_type: 'buildpack') unless guids_with_buildpack.empty?
          self[table].where(guid: guids_with_cnb,       lifecycle_type: nil).update(lifecycle_type: 'cnb')       unless guids_with_cnb.empty?
          self[table].where(guid: guids_docker,         lifecycle_type: nil).update(lifecycle_type: 'docker')    unless guids_docker.empty?
        end

        break if guids.size < batch_size
      end
    end
  end

  down do
    # Intentionally left empty: backfilled values are correct and should not be reverted
  end
end
