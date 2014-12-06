module VCAP::CloudController
  class AppCreateMessage
    attr_reader :name, :space_guid
    attr_accessor :error

    def self.create_from_http_request(body)
      opts = body && MultiJson.load(body)
      AppCreateMessage.new(opts)
    rescue MultiJson::ParseError => e
      message = AppCreateMessage.new({})
      message.error = e.message
      message
    end

    def initialize(opts)
      @name       = opts['name']
      @space_guid = opts['space_guid']
    end
  end

  class AppUpdateMessage
    attr_reader :guid, :name
    attr_accessor :error

    def self.create_from_http_request(guid, body)
      opts = body && MultiJson.load(body)
      AppUpdateMessage.new(opts.merge('guid' => guid))
    rescue MultiJson::ParseError => e
      message = AppUpdateMessage.new({})
      message.error = e.message
      message
    end

    def initialize(opts)
      @guid = opts['guid']
      @name = opts['name']
    end
  end

  class AppsHandler
    class Unauthorized < StandardError; end
    class DeleteWithProcesses < StandardError; end
    class DuplicateProcessType < StandardError; end

    def show(guid, access_context)
      app = AppModel.find(guid: guid)
      return nil if app.nil? || access_context.cannot?(:read, app)
      app
    end

    def create(message, access_context)
      app            = AppModel.new
      app.name       = message.name
      app.space_guid = message.space_guid

      raise Unauthorized if access_context.cannot?(:create,  app)

      app.save
      app
    end

    def update(message, access_context)
      app = AppModel.find(guid: message.guid)
      return nil if app.nil?

      app.db.transaction do
        app.lock!

        app.name = message.name

        raise Unauthorized if access_context.cannot?(:update, app)

        app.save
      end

      app
    end

    def delete(guid, access_context)
      app = AppModel.find(guid: guid)
      return nil if app.nil?

      app.db.transaction do
        app.lock!

        return nil if access_context.cannot?(:delete, app)
        raise DeleteWithProcesses if app.processes.any?

        app.destroy
      end
      true
    end

    def add_process(app, process, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)

      app.db.transaction do
        app.lock!

        raise DuplicateProcessType if app.processes.any? { |p| p.type == process.type }
        app.add_process_by_guid(process.guid)
      end
    end

    def remove_process(app, process, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)
      app.remove_process_by_guid(process.guid)
    end
  end
end
