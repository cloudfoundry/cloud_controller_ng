Sequel.migration do
  up do
    processes_with_commands = self[:processes]

    processes_with_commands.each do |process_record|
      app_record = self[:apps].where(guid: process_record[:app_guid]).for_update.first
      droplet_record = self[:droplets].where(guid: app_record[:droplet_guid]).for_update.first

      # for_update will acquire a row level lock in the database
      # We need to force the dataset to evaluate by calling #first to get it to take effect
      self[:processes].where(guid: process_record[:guid]).for_update.first

      next unless droplet_record
      begin
        droplet_commands_by_type = JSON.parse(droplet_record[:process_types])
      rescue JSON::ParserError
      end
      droplet_command = droplet_commands_by_type && droplet_commands_by_type[process_record[:type]]

      begin
        process_metadata = JSON.parse(process_record[:metadata])
      rescue JSON::ParserError
      end
      process_metadata_command = process_metadata && process_metadata['command']

      process_command = process_record[:command]

      if process_metadata_command && process_record[:command].nil?
        process_command = process_metadata_command
      end

      if droplet_command == process_command
        process_command = nil
      end

      fields_to_update = {}

      if process_command != process_record[:command]
        fields_to_update[:command] = process_command
      end

      if process_metadata_command
        fields_to_update[:metadata] = process_metadata.except('command').to_json
      end

      if fields_to_update.any?
        self[:processes].where(guid: process_record[:guid]).update(fields_to_update)
      end
    end
  end

  down do
  end
end
