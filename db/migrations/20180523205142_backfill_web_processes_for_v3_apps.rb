Sequel.migration do
  up do
    app_guids_with_web_processes = self[:processes].select(:app_guid).where(type: 'web')
    app_records_without_web_processes = self[:apps].select(:guid, :desired_state).exclude(guid: app_guids_with_web_processes).all

    app_records_without_web_processes.each do |app_record|
      app_guid = app_record[:guid]
      process_hash = {
        guid: app_guid,
        app_guid: app_guid,
        type: 'web',
        instances: 0,
        memory: nil,
        disk_quota: nil,
        file_descriptors: nil,
        state: app_record[:desired_state],
        diego: true,
        health_check_type: 'port',
        enable_ssh: nil,
        created_at: Sequel::CURRENT_TIMESTAMP
      }

      self[:processes].insert(process_hash)
    end
  end

  down do
  end
end
