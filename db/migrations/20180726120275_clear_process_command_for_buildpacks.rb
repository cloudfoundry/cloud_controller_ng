Sequel.migration do
  up do
    processes_with_commands = self[:processes].exclude(command: nil)

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

      if droplet_commands_by_type && droplet_commands_by_type[process_record[:type]] == process_record[:command]
        self[:processes].where(guid: process_record[:guid]).update(command: nil)
      end
    end
  end

  down do
  end
end
