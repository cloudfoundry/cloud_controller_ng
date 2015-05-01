require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
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

    def initialize(paginator=SequelPaginator.new)
      @paginator         = paginator
    end

    def show(guid, access_context)
      app = AppModel.find(guid: guid)
      return nil if app.nil? || access_context.cannot?(:read, app)
      app
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

        Event.create({
          type: 'audit.app.add_process',
          actee: app.guid,
          actee_type: 'v3-app',
          actee_name: app.name,
          actor: access_context.user.guid,
          actor_type: 'user',
          actor_name: access_context.user_email,
          space_guid: app.space_guid,
          organization_guid: app.space.organization.guid,
          timestamp: Sequel::CURRENT_TIMESTAMP,
        })

        app.add_process_by_guid(process.guid)
        routes = app.routes_dataset.where(type: process.type)
        routes.each do |route|
          real_process = App.find(guid: process.guid)
          real_process.add_route(route)
        end
      end
    end

    def remove_process(app, process, access_context)
      raise Unauthorized if access_context.cannot?(:update, app)
      app.remove_process_by_guid(process.guid)

      Event.create({
        type: 'audit.app.remove_process',
        actee: app.guid,
        actee_type: 'v3-app',
        actee_name: app.name,
        actor: access_context.user.guid,
        actor_type: 'user',
        actor_name: access_context.user_email,
        space_guid: app.space_guid,
        organization_guid: app.space.organization.guid,
        timestamp: Sequel::CURRENT_TIMESTAMP,
      })
    end
  end
end
