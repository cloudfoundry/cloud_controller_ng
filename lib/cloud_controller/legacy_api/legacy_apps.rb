# Copyright (c) 2009-2012 VMware, Inc.


module VCAP::CloudController
  class LegacyApps
    include VCAP::CloudController::Errors

    # For reference, this is an example of the old format:
    # [
    #   {
    #     "name": "ccng",
    #     "staging": {
    #       "model": "standalone",
    #       "stack": "ruby19"
    #     },
    #     "uris": [
    #       "ccng.p02.rbconsvcs.com"
    #     ],
    #     "instances": 1,
    #     "runningInstances": 1,
    #     "resources": {
    #       "memory": 128,
    #       "disk": 2048,
    #       "fds": 256
    #     },
    #     "state": "STARTED",
    #     "services": [
    #       "postgresql-1a0bb"
    #     ],
    #     "version": "1973be5c9c07005b930a2637cac2108c474421a1-1",
    #     "env": [
    #
    #     ],
    #     "meta": {
    #       "command": "bin/cloud_controller -m",
    #       "debug": null,
    #       "console": false,
    #       "version": 6,
    #       "created": 1340128764
    #     }
    #   }
    # ]

    def enumerate
      # FIXME: add a flag to fully disable pagination.  Don't allow it
      # to be a http query parm in the real api.
      opts = { "q" => "app_space_guid:#{default_app_space.guid}" }
      api_resp = legacy_api_inline_relations(nil, opts).dispatch(:enumerate)

      apps = Yajl::Parser.parse(api_resp)
      legacy_resp = apps["resources"].map do |app|
        legacy_app_encoding(app)
      end

      Yajl::Encoder.encode(legacy_resp)
    end

    # REQUEST_BODY:
    #
    # {"name":"foopeb","staging":{"framework":"sinatra","runtime":null},
    #  "uris":["foopeb.http://localhost:8181"],"instances":1,"resources":{"memory":128}}
    def create
      # TODO: use json schema
      legacy_attrs = Yajl::Parser.parse(request.body)

      raise InvalidRequest unless legacy_attrs
      raise InvalidRequest unless legacy_attrs["staging"]
      raise InvalidRequest unless legacy_attrs["resources"]

      logger.debug "legacy create: #{legacy_attrs}"

      framework = Models::Framework.find(:name => legacy_attrs["staging"]["framework"])
      framework_guid = framework ? framework.guid : nil

      # FIXME: whoh there. do a proper conversion based on the framework
      runtime_name = legacy_attrs["staging"]["runtime"] || "ruby18"
      runtime = Models::Runtime.find(:name => runtime_name)
      runtime_guid = runtime ? runtime.guid : nil

      attrs = {
        :name => legacy_attrs["name"],
        :app_space_guid => default_app_space.guid,
        :framework_guid => framework_guid,
        :runtime_guid => runtime_guid,
        :memory => legacy_attrs["resources"]["memory"],
        :instances => legacy_attrs["instances"]
      }

      legacy_req = Yajl::Encoder.encode(attrs)
      legacy_api_inline_relations(legacy_req).dispatch(:create)
      HTTP::OK
    end

    def read(name)
      app = app_from_name(name)
      api_resp = legacy_api_inline_relations.dispatch(:read, app.guid)
      app_json = Yajl::Parser.parse(api_resp)
      legacy_resp = legacy_app_encoding(app_json)
      Yajl::Encoder.encode(legacy_resp)
    end

    def update(name)
      app = app_from_name(name)
      (_, api_resp) = legacy_api_inline_relations.dispatch(:update, app.guid)
      app_json = Yajl::Parser.parse(api_resp)
      legacy_resp = legacy_app_encoding(app_json)
      Yajl::Encoder.encode(legacy_resp)
    end

    def delete(name)
      app = app_from_name(name)
      api_resp = legacy_api.dispatch(:delete, app.guid)
      HTTP::OK
    end

    def upload_resources
      # TODO
      HTTP::OK
    end

    def default_app_space
      raise NotAuthorized unless @user
      raise LegacyApiWithoutDefaultAppSpace unless @user.default_app_space
      @user.default_app_space
    end

    def legacy_api(body = nil, params = {})
      body ||= request.body
      VCAP::CloudController::App.new(user, logger, body, params)
    end

    def legacy_api_inline_relations(body = nil, params = {})
      legacy_api(body, params.merge("inline-relations-depth" => 1))
    end

    def app_from_name(name)
      app = Models::App.find(:name => name, :app_space => default_app_space)
      raise AppNotFound.new(name) unless app
      app
    end

    def legacy_app_encoding(app)
      {
        :name => app["entity"]["name"],
        :staging => {
          :model => app["entity"]["framework"]["entity"]["name"], # TODO: is this correct?
          :stack => "TODO",
        },
        :uris => [], # TODO
        :instances => app["entity"]["instances"],
        :runningInstance => 0, # TODO
        :resources => {
          :memory => app["entity"]["memory"],
          :disk => app["entity"]["disk"],
          :fds => app["entity"]["fds"]
        },
        :state => "TODO",
        :services => [], # TODO
        :version => "TODO",
        :env => [], # TODO
        :meta =>  {
          # TODO
        }
      }
    end

    private

    def self.setup_routes
      klass = self
      controller.get "/apps" do
        klass.new(@config, logger, request).enumerate
      end

      controller.get "/apps/:name" do |name|
        klass.new(@config, logger, request).read(name)
      end

      controller.put "/apps/:name" do |name|
        klass.new(@config, logger, request).update(name)
      end

      controller.delete "/apps/:name" do |name|
        klass.new(@config, logger, request).delete(name)
      end

      controller.post "/apps" do
        klass.new(@config, logger, request).create
      end

      controller.post "/apps/:name/application" do
        klass.new(@config, logger, request).upload_resources
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
  end
end
