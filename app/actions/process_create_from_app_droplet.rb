require 'actions/process_create'

module VCAP::CloudController
  class ProcessCreateFromAppDroplet
    class ProcessTypesNotFound < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.process_create_from_app_droplet')
    end

    def create(app)
      @logger.info('create', guid: app.guid)

      unless app.droplet && app.droplet.process_types
        @logger.warn('no process_types found', guid: app.guid)
        raise ProcessTypesNotFound.new("Unable to create process types for this app's droplet. Please provide a droplet with valid process types.")
      end

      create_requested_processes(app, app.droplet.process_types)
    end

    private

    def create_requested_processes(app, process_types)
      @logger.debug('using the droplet process_types', guid: app.guid)

      process_types.each_key { |type| create_process(app, type.to_s) }
    end

    def create_process(app, type)
      if app.processes_dataset.where(type: type).empty?
        ProcessCreate.new(@user_audit_info).create(app, { type: type })
      end
    end
  end
end
