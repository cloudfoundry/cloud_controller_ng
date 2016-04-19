require 'cloud_controller/procfile'
require 'actions/process_create'

module VCAP::CloudController
  class CurrentProcessTypes
    class DropletNotFound < StandardError; end
    class ProcessTypesNotFound < StandardError; end

    def initialize(user_guid, user_email)
      @user_guid  = user_guid
      @user_email = user_email
      @logger     = Steno.logger('cc.action.current_process_types')
    end

    def process_current_droplet(app)
      @logger.info('process_current_droplet', guid: app.guid)

      if app.droplet && app.droplet.process_types
        @logger.debug('using the droplet process_types', guid: app.guid)
        evaluate_processes(app, app.droplet.process_types)
      else
        @logger.warn('no process_types found', guid: app.guid)
        raise ProcessTypesNotFound
      end
    end

    private

    attr_reader :user_guid, :user_email

    def evaluate_processes(app, process_types)
      types = []
      process_types.each do |(type, command)|
        type = type.to_s
        types << type
        add_or_update_process(app, type, command)
      end

      processes = app.processes_dataset.where(Sequel.~(type: types))
      ProcessDelete.new(user_guid, user_email).delete(processes.all)
    end

    def add_or_update_process(app, type, command)
      existing_process = app.processes_dataset.where(type: type).first
      if existing_process
        ProcessUpdate.new(user_guid, user_email).update(existing_process, ProcessUpdateMessage.new({ command: command }))
      else
        ProcessCreate.new(user_guid, user_email).create(app, { type: type, command: command })
      end
    end
  end
end
