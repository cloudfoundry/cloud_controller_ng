require 'cloud_controller/procfile'

module VCAP::CloudController
  class ProcfileParse
    class DropletNotFound < StandardError; end
    class ProcfileNotFound < StandardError; end

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
      @logger = Steno.logger('cc.action.procfile_parse')
    end

    def process_procfile(app)
      @logger.info('proccess_procfile', guid: app.guid)

      if app.desired_droplet && app.desired_droplet.procfile
        @logger.debug('using the droplet procfile', guid: app.guid)

        procfile = Procfile.load(app.desired_droplet.procfile)
        converge_on_procfile(app, procfile)
        procfile
      else
        @logger.warn('no procfile found', guid: app.guid)
        raise ProcfileNotFound
      end
    end

    private

    attr_reader :user_guid, :user_email

    def converge_on_procfile(app, procfile_hash)
      types = []
      procfile_hash.each do |(type, command)|
        type = type.to_s
        types << type
        process_procfile_line(app, type, command)
      end
      processes = app.processes_dataset.where(Sequel.~(type: types))
      ProcessDelete.new.delete(processes.all)
    end

    def process_procfile_line(app, type, command)
      existing_process = app.processes_dataset.where(type: type).first
      if existing_process
        message = { command: command }
        existing_process.update(message)
        process_event_repository.record_app_update(existing_process, app.space, user_guid, user_email, message)
      else
        message = {
          command: command,
          type: type,
          space: app.space,
          name: "v3-#{app.name}-#{type}",
          metadata: {},
        }
        app.add_process(message)
      end
    end

    def process_event_repository
      Repositories::Runtime::AppEventRepository.new
    end
  end
end
