require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class AppsRepository
    def get_apps(access_context, facets)
      dataset = nil
      if access_context.roles.admin?
        dataset = AppModel.dataset
      else
        dataset = AppModel.user_visible(access_context.user)
      end

      if facets['names']
        dataset = dataset.where(name: facets['names'])
      end
      if facets['space_guids']
        dataset = dataset.where(space_guid: facets['space_guids'])
      end
      if facets['organization_guids']
        dataset = dataset.where(space_guid: Organization.where(guid: facets['organization_guids']).map(&:spaces).flatten.map(&:guid))
      end
      if facets['guids']
        dataset = dataset.where(guid: facets['guids'])
      end
      dataset
    end
  end

  class AppCreateMessage
    attr_reader :name, :space_guid
    attr_accessor :error

    def self.create_from_http_request(body)
      opts = body && MultiJson.load(body)
      raise MultiJson::ParseError.new('invalid request body') unless opts.is_a?(Hash)
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
    attr_reader :guid, :name, :desired_droplet_guid
    attr_accessor :error

    def self.create_from_http_request(guid, body)
      opts = body && MultiJson.load(body)
      raise MultiJson::ParseError.new('invalid request body') unless opts.is_a?(Hash)
      AppUpdateMessage.new(opts.merge('guid' => guid))
    rescue MultiJson::ParseError => e
      message = AppUpdateMessage.new({})
      message.error = e.message
      message
    end

    def initialize(opts)
      @guid = opts['guid']
      @name = opts['name']
      @desired_droplet_guid = opts['desired_droplet_guid']
    end
  end

  class AppsHandler
    class Unauthorized < StandardError; end
    class DeleteWithProcesses < StandardError; end
    class DuplicateProcessType < StandardError; end
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end
    class IncorrectProcessSpace < StandardError; end
    class IncorrectPackageSpace < StandardError; end

    def initialize(processes_handler, paginator=SequelPaginator.new, apps_repository=AppsRepository.new)
      @processes_handler = processes_handler
      @paginator = paginator
      @apps_repository = apps_repository
    end

    def show(guid, access_context)
      app = AppModel.find(guid: guid)
      return nil if app.nil? || access_context.cannot?(:read, app)
      app
    end

    def list(pagination_options, access_context, facets={})
      dataset = @apps_repository.get_apps(access_context, facets)

      @paginator.get_page(dataset, pagination_options)
    end

    def create(message, access_context)
      app            = AppModel.new
      app.name       = message.name
      app.space_guid = message.space_guid

      raise InvalidApp.new('Space was not found') if Space.find(guid: message.space_guid).nil?
      raise Unauthorized if access_context.cannot?(:create,  app)

      app.save
      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    def update(message, access_context)
      app = AppModel.find(guid: message.guid)
      return nil if app.nil?

      app.db.transaction do
        app.lock!

        app.name = message.name unless message.name.nil?
        if message.desired_droplet_guid
          droplet = DropletModel.find(guid: message.desired_droplet_guid)
          raise DropletNotFound if droplet.nil?
          raise DropletNotFound if droplet.app_guid != app.guid
          app.desired_droplet_guid = message.desired_droplet_guid
        end

        raise Unauthorized if access_context.cannot?(:update, app)

        app.save

        web_process = app.processes.find { |p| p.type == 'web' }
        update_web_process_name(web_process, message.name, access_context) unless web_process.nil?
      end

      return app

    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    def delete(guid, access_context)
      app = AppModel.find(guid: guid)
      return nil if app.nil?

      app.db.transaction do
        app.lock!

        raise Unauthorized if access_context.cannot?(:delete, app)
        raise DeleteWithProcesses if app.processes.any?

        app.destroy
      end
      true
    end

    def add_process(app, process, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)
      raise IncorrectProcessSpace if app.space_guid != process.space_guid

      app.db.transaction do
        app.lock!

        app.processes.each do |p|
          return if p.guid == process.guid
          raise DuplicateProcessType if p.type == process.type
        end

        app.add_process_by_guid(process.guid)
      end
    end

    def add_package(app, package, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)
      raise IncorrectPackageSpace if app.space_guid != package.space_guid

      app.db.transaction do
        app.lock!
        app.add_package_by_guid(package.guid)
      end
      package.reload
    end

    def update_web_process_name(process, name, access_context)
      opts = { 'name' => name }
      msg = ProcessUpdateMessage.new(process.guid, opts)
      @processes_handler.update(msg, access_context)
    end

    def remove_process(app, process, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)
      app.remove_process_by_guid(process.guid)
    end
  end
end
