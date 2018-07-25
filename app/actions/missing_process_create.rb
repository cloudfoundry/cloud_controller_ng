require 'actions/process_create'

module VCAP::CloudController
  class MissingProcessCreate
    class ProcessTypesNotFound < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.process_upsert_from_droplet')
    end

    def create_from_current_droplet(app)
      @logger.info('process_current_droplet', guid: app.guid)

      if app.droplet&.process_types
        @logger.debug('using the droplet process_types', guid: app.guid)
        evaluate_processes(app, app.droplet.process_types)
      else
        @logger.warn('no process_types found', guid: app.guid)
        raise ProcessTypesNotFound
      end
    end

    private

    def evaluate_processes(app, process_types)
      process_types.each_key { |type| create_process(app, type.to_s) }
    end

    def create_process(app, type)
      if app.processes_dataset.where(type: type).count == 0
        ProcessCreate.new(@user_audit_info).create(app, { type: type })
      end
    end
  end
end
