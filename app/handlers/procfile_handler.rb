require 'handlers/processes_handler'

module VCAP::CloudController
  class ProcfileHandler
    class Unauthorized < StandardError; end

    def initialize(apps_handler, processes_handler)
      @apps_handler = apps_handler
      @processes_handler = processes_handler
    end

    def process_procfile(app, procfile, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)

      app.db.transaction do
        app.lock!
        types = []
        procfile.each do |(type, command)|
          type = type.to_s
          types << type
          process_procfile_line(app, type, command, access_context)
        end

        processes = @processes_handler.raw_list(access_context, filter: { app_guid: app.guid }, exclude: { type: types })
        processes.map(&:guid).each do |process_guid|
          @processes_handler.delete(access_context, filter: { guid: process_guid })
        end
      end
    end

    private

    def process_procfile_line(app, type, command, access_context)
      base_message = { app_guid: app.guid, space_guid: app.space_guid }

      existing_process = @processes_handler.raw_list(access_context, filter: { app_guid: app.guid, type: type }).first
      if existing_process
        update_message = ProcessUpdateMessage.new(existing_process.guid, command: command)
        @processes_handler.update(update_message, access_context)
      else
        create_message = ProcessCreateMessage.new(base_message.merge(type: type, command: command))
        process = @processes_handler.create(create_message, access_context)
        @apps_handler.add_process(app, process, access_context)
      end
    end
  end
end
