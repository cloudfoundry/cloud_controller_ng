# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyApps < LegacyApiBase
    include VCAP::CloudController::Errors

    def initialize(*args)
      raise NotAuthenticated unless user
      super
    end

    def enumerate
      logger.debug "enumerate apps request"

      resp = default_app_space.apps.map do |app|
        legacy_app_encoding(app)
      end

      logger.debug "enumerate apps request returning #{resp}"
      Yajl::Encoder.encode(resp)
    end

    def create
      logger.debug "create app"
      req = request_from_legacy_json(request.body)
      VCAP::CloudController::App.new(logger, req).dispatch(:create)
      HTTP::OK
    end

    def read(name)
      logger.debug "read app request name: #{name}"

      app = app_from_name(name)
      resp = legacy_app_encoding(app)

      logger.debug "read app returning #{resp}"
      Yajl::Encoder.encode(resp)
    end

    def update(name)
      logger.debug "update app"
      app = app_from_name(name)
      req = request_from_legacy_json(request.body)
      VCAP::CloudController::App.new(logger, req).dispatch(:update, app.guid)
      HTTP::OK
    end

    def delete(name)
      logger.debug "delete app"
      app = app_from_name(name)
      VCAP::CloudController::App.new(logger).dispatch(:delete, app.guid)
      HTTP::OK
    end

    private

    def legacy_app_encoding(app)
      {
        :name => app.name,
        :staging => {
          :model => app.framework.name,
          :stack => app.runtime.name,
        },
        :uris => [], # TODO when routes are finalized
        :instances => app.instances,
        :runningInstance => 0, # TODO: when HM integration is done
        :resources => {
          :memory => app.memory,
          :disk => app.disk_quota,
          :fds => app.file_descriptors,
        },
        :state => app.state,
        :services => app.service_bindings.map { |b| b.service_instance.name },
        :version => "TODO", # TODO: fill in when running app support is done
        :env => (app.environment_json || {}).to_hash,
        :meta =>  {
          # TODO when running app support is done
        }
      }
    end

    def app_from_name(name)
      app = Models::App.user_visible[:name => name, :app_space => default_app_space]
      raise AppNotFound.new(name) unless app
      app
    end

    def request_from_legacy_json(legacy_json)
      hash = Yajl::Parser.parse(legacy_json)
      raise InvalidRequest unless hash

      req = {
        :app_space_guid => default_app_space.guid
      }

      if name = hash["name"]
        req[:name] = name
      end

      if staging = hash["staging"]
        if framework_name = staging["framework"]
          framework = Models::Framework.find(:name => framework_name)
          raise FrameworkNotFound.new(framework_name) unless framework
          req[:framework_guid] = framework.guid
        end

        # apparently runtime wasn't required in v1 and should default to
        # ruby18
        runtime_name = staging["runtime"] || "ruby18"
        runtime = Models::Runtime.find(:name => runtime_name)
        raise RuntimeNotFound.new(runtime_name) unless runtime
        req[:runtime_guid] = runtime.guid
      end

      if resources = hash["resources"]
        ["memory", "instances"].each do |k|
          req[k] = resources[k] if resources[k]
        end
      end

      logger.debug "legacy request: #{hash} -> #{req}"
      Yajl::Encoder.encode(req)
    end

    def self.setup_routes
      controller.get "/apps" do
        LegacyApps.new(@config, logger, request).enumerate
      end

      controller.post "/apps" do
        LegacyApps.new(@config, logger, request).create
      end

      controller.get "/apps/:name" do |name|
        LegacyApps.new(@config, logger, request).read(name)
      end

      controller.put "/apps/:name" do |name|
        LegacyApps.new(@config, logger, request).update(name)
      end

      controller.delete "/apps/:name" do |name|
        LegacyApps.new(@config, logger, request).delete(name)
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
  end
end
