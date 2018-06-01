require 'actions/process_create'

module VCAP::CloudController
  class ProcessUpsertFromDroplet
    class DropletNotFound < StandardError; end
    class ProcessTypesNotFound < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.process_upsert_from_droplet')
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

    def evaluate_processes(app, process_types)
      types = []
      process_types.each do |(type, command)|
        type = type.to_s
        types << type
        add_or_update_process(app, type, command)
      end
    end

    def add_or_update_process(app, type, command)
      existing_process = app.processes_dataset.first(type: type)

      if existing_process
        ProcessUpdate.new(@user_audit_info).update(existing_process, ProcessUpdateMessage.new, NonManifestStrategy)
      else
        ProcessCreate.new(@user_audit_info).create(app, { type: type })
      end
    end
  end
end
