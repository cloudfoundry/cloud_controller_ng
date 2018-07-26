Sequel.migration do
  up do
    processes_with_commands = self[:processes].exclude(command: nil)

    processes_with_commands.each do |process_record|
      app_record = self[:apps].where(guid: process_record[:app_guid]).first
      droplet_record = self[:droplets].where(guid: app_record[:droplet_guid]).first

      begin
        droplet_process_types = JSON.parse(droplet_record[:process_types])
      rescue JSON::ParserError
      end

      if droplet_process_types && droplet_process_types[process_record[:type]] == process_record[:command]
        self[:processes].where(guid: process_record[:guid]).update(command: nil)
      end
    end
  end

  down do
  end
end
