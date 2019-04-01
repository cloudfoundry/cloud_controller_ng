Sequel.migration do
  up do
    missing_attributes_query = Sequel.lit(
      'memory IS NULL OR disk_quota IS NULL OR file_descriptors is NULL OR enable_ssh is NULL'
    )
    web_processes_missing_attributes = self[:processes].where(missing_attributes_query)

    web_processes_missing_attributes.each do |process_record|
      process_guid = process_record[:guid]
      fields_to_update = {}

      # default to cc.default_app_memory
      fields_to_update[:memory] = 1024 if process_record[:memory].nil?

      # default to cc.default_app_disk_in_mb
      fields_to_update[:disk_quota] = 1024 if process_record[:disk_quota].nil?

      # default to cc.instance_file_descriptor_limit
      fields_to_update[:file_descriptors] = 16384 if process_record[:file_descriptors].nil?

      # processes.enable_ssh is no longer used, but we will set it to the database default of false to match other processes
      # apps.enable_ssh is the source of truth
      fields_to_update[:enable_ssh] = false if process_record[:enable_ssh].nil?

      self[:processes].where(guid: process_guid).update(fields_to_update) unless fields_to_update.empty?
    end
  end

  down do
  end
end
