require 'cloud_controller/procfile'
require 'repositories/runtime/process_event_repository'

module VCAP::CloudController
  class CurrentProcessTypes
    class DropletNotFound < StandardError; end
    class ProcessTypesNotFound < StandardError; end

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
      @logger = Steno.logger('cc.action.current_process_types')
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
        message = { command: command }
        existing_process.update(message)
      else
        message = {
          diego:             true,
          command:           command,
          type:              type,
          space:             app.space,
          name:              "v3-#{app.name}-#{type}",
          metadata:          {},
          instances:         type == 'web' ? 1 : 0,
          health_check_type: type == 'web' ? 'port' : 'process'
        }

        app.class.db.transaction do
          process = app.add_process(message)

          RouteMappingModel.where(app_guid: app.guid, process_type: type).select_map(:route_guid).each do |route_guid|
            process.add_route_by_guid(route_guid)
          end

          process_event_repository.record_create(process, user_guid, user_email)
        end
      end
    end

    def process_event_repository
      Repositories::Runtime::ProcessEventRepository
    end
  end
end
