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
    attr_reader :name, :space_guid, :environment_variables
    attr_accessor :error

    def self.create_from_http_request(body)
      opts = body && MultiJson.load(body)
      raise MultiJson::ParseError.new('invalid request body') unless opts.is_a?(Hash)
      AppCreateMessage.new(opts)
    rescue MultiJson::ParseError => e
      message       = AppCreateMessage.new({})
      message.error = e.message
      message
    end

    def initialize(opts)
      @name                  = opts['name']
      @space_guid            = opts['space_guid']
      @environment_variables = opts['environment_variables']
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

    def initialize(packages_handler, droplets_handler, processes_handler, paginator=SequelPaginator.new, apps_repository=AppsRepository.new)
      @packages_handler  = packages_handler
      @droplets_handler  = droplets_handler
      @processes_handler = processes_handler
      @paginator         = paginator
      @apps_repository   = apps_repository
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
        routes = app.routes_dataset.where(type: process.type)
        routes.each do |route|
          real_process = App.find(guid: process.guid)
          real_process.add_route(route)
        end
      end
    end

    def update_web_process_name(process, name, access_context)
      opts = { 'name' => name }
      msg  = ProcessUpdateMessage.new(process.guid, opts)
      @processes_handler.update(msg, access_context)
    end

    def remove_process(app, process, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)
      app.remove_process_by_guid(process.guid)
    end
  end
end
