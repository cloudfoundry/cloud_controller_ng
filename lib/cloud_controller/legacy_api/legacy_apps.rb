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

      resp = default_space.apps.map do |app|
        legacy_app_encoding(app)
      end

      logger.debug "enumerate apps request returning #{resp}"
      Yajl::Encoder.encode(resp)
    end

    def create
      logger.debug "create app"
      req = request_from_legacy_create_json(body)
      (_, _, resp) = VCAP::CloudController::App.new(config, logger, env, params, req).
        dispatch(:create)

      resp_hash = Yajl::Parser.parse(resp)

      app_name = resp_hash.fetch("entity").fetch("name")
      app_url = "/apps/%s" % app_name
      body = {
        "result"    => "success",
        "redirect"  => app_url,
      }
      [
        HTTP::FOUND,
        { "Location" => app_url },
        Yajl::Encoder.encode(body)
      ]
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
      req = request_from_legacy_update_json(body, app)
      VCAP::CloudController::App.new(config, logger, env, params, req).
        dispatch(:update, app.guid)
      app.refresh

      HTTP::OK
    end

    def delete(name)
      logger.debug "delete app"

      app = app_from_name(name)
      VCAP::CloudController::App.new(config, logger, env, params, body).
        dispatch(:delete, app.guid)

      HTTP::OK
    end

    def crashes(name)
      logger.debug "crashes app request name: #{name}"

      app = app_from_name(name)
      api = VCAP::CloudController::Crashes.new(config, logger, env, params, body)
      resp_json = api.dispatch(:crashes, app.guid)
      resp = Yajl::Parser.parse(resp_json)
      Yajl::Encoder.encode(:crashes => resp)
    end

    def upload(name)
      logger.debug "upload app request name: #{name}"
      app = app_from_name(name)
      VCAP::CloudController::AppBits.new(config, logger, env, params, body).dispatch(:upload, app.guid)
      HTTP::OK
    end

    def files(name, instance_id, path = nil)
      msg = "files app request name: #{name}, instance_id: #{instance_id}"
      msg << ", path: #{path}"

      logger.debug msg

      app = app_from_name(name)
      VCAP::CloudController::Files.new(config, logger, env, params, body).
        dispatch(:files, app.guid, instance_id, path, :allow_redirect => false)
    end

    def stats(name)
      logger.debug "stats app request name: #{name}"

      app = app_from_name(name)
      VCAP::CloudController::Stats.new(config, logger, env, params, body).
        dispatch(:stats, app.guid, :allow_stopped_state => true)
    end

    def instances(name)
      logger.debug "instances app request name: #{name}"

      app = app_from_name(name)
      api = VCAP::CloudController::Instances.new(config, logger, env, params, body)
      resp_json = api.dispatch(:instances, app.guid)

      hash = Yajl::Parser.parse(resp_json)
      legacy_resp = []
      hash.each do |k, v|
        legacy_resp << {:index => k.to_i}.merge(v)
      end
      Yajl::Encoder.encode({:instances => legacy_resp})
    end

    private

    def legacy_app_encoding(app)
      {
        :name => app.name,
        :staging => {
          :model => app.framework.name,
          :stack => app.runtime.name,
        },
        :uris => app.uris,
        :instances => app.instances,
        :runningInstances => app.running_instances,
        :resources => {
          :memory => app.memory,
          :disk => app.disk_quota,
          :fds => app.file_descriptors,
        },
        :state => app.state,
        :services => app.service_bindings.map { |b| b.service_instance.name },
        :version => app.version,
        # TODO: quote / escape env vars
        :env => (app.environment_json || {}).map {|k,v| "#{k}=#{v}"},
        :meta =>  app.metadata,
      }
    end

    def app_from_name(name)
      app = Models::App.user_visible[:name => name, :space => default_space]
      raise AppNotFound.new(name) unless app
      app
    end

    def request_from_legacy_create_json(legacy_json)
      around_translate(legacy_json) do |hash|
        req = translate_legacy_create_json(hash)
        logger.debug "legacy request: #{hash} -> #{req}"
        req
      end
    end

    def request_from_legacy_update_json(legacy_json, app)
      around_translate(legacy_json) do |hash|
        req = translate_legacy_update_json(hash, app)
        logger.debug "legacy request: #{hash} -> #{req}"
        req
      end
    end

    def translate_legacy_update_json(hash, app)
      req = translate_legacy_create_json(hash)

      if bindings = hash["services"]
        req[:service_binding_guids] = bindings.map do |name|
          svc_instance = default_space.service_instances_dataset[:name => name]
          raise ServiceInstanceInvalid.new(name) unless svc_instance

          if binding = svc_instance.service_bindings_dataset[:app => app]
            binding.guid
          else
            req_hash = {
              :app_guid => app.guid,
              :service_instance_guid => svc_instance.guid
            }
            binding_req = Yajl::Encoder.encode(req_hash)
            (_, _, binding_json) = VCAP::CloudController::ServiceBinding.new(config, logger, env, params, binding_req).dispatch(:create)
            binding_resp = Yajl::Parser.parse(binding_json)
            binding_resp["metadata"]["guid"]
          end
        end
      end

      req
    end

    def translate_legacy_create_json(hash)
      req = {
        :space_guid => default_space.guid
      }

      ["name", "instances", "state", "console"].each do |k|
        req[k] = hash[k] if hash.has_key?(k)
      end

      if staging = hash["staging"]
        framework = nil
        if framework_name = staging["framework"] || staging["model"]
          framework = Models::Framework.find(:name => framework_name)
          raise FrameworkInvalid.new(framework_name) unless framework
          req[:framework_guid] = framework.guid
        end

        runtime_name = staging["runtime"] || staging["stack"]
        runtime_name ||= default_runtime_for_framework(framework)
        if runtime_name
          runtime = Models::Runtime.find(:name => runtime_name)
          raise RuntimeInvalid.new(runtime_name) unless runtime
          req[:runtime_guid] = runtime.guid
        end

        req[:command] = staging["command"] if staging["command"]
      end

      if resources = hash["resources"]
        ["memory", "instances"].each do |k|
          req[k] = resources[k] if resources[k]
        end
      end

      if uris = hash["uris"]
        req[:route_guids] = uris.map do |uri|
          # TODO: change when we allow subdomains
          (host, domain_name) = uri.split(".", 2)
          domain = default_space.domains_dataset[:name => domain_name]
          raise DomainInvalid.new(domain_name) unless domain
          visible_routes = Models::Route.filter(
            Models::Route.user_visibility_filter(user)
          )
          route = visible_routes[:host => host, :domain => domain]
          if route
            route.guid
          else
            req_hash = {
              :host => host,
              :domain_guid => domain.guid,
              :space_guid => default_space.guid,
            }
            route_req = Yajl::Encoder.encode(req_hash)
            (_, _, route_json) = VCAP::CloudController::Route.new(config, logger, env, params, route_req).dispatch(:create)
            route_resp = Yajl::Parser.parse(route_json)
            route_resp["metadata"]["guid"]
          end
        end
      end

      if hash.has_key?("env")
        env_array = hash["env"]
        raise BadQueryParameter, "env should be an array" unless env_array.is_a?(Array)
        env_hash = {}
        env_array.each do |kv|
          raise BadQueryParameter, "env var assignment format expected" unless kv.index('=')
          k,v = kv.split('=', 2)
          env_hash[k] = v
        end
        req["environment_json"] = env_hash
      end

      req
    end

    # takes an old json-encoded request, runs a block on the decoded hash and
    # returns the new encoded json
    # @param [String] old_json  old json-encoded request hash
    # @yieldparam [Hash]  decoded hash decoded from old_json
    # @yieldreturn  [Hash] translated hash
    # @return [String]  new json
    def around_translate(old_json, &translate)
      decoded = Yajl::Parser.parse(old_json)
      translated = translate.call(decoded)
      Yajl::Encoder.encode(translated)
    end

    def default_runtime_for_framework(framework)
      return unless framework
      framework.internal_info["runtimes"].each do |runtime|
        runtime.each do |runtime_name, runtime_info|
          return runtime_name if runtime_info["default"] == true
        end
      end
      nil
    end

    def self.setup_routes
      get    "/apps",                                      :enumerate
      post   "/apps",                                      :create
      get    "/apps/:name",                                :read
      put    "/apps/:name",                                :update
      delete "/apps/:name",                                :delete
      get    "/apps/:name/crashes",                        :crashes
      post   "/apps/:name/application",                    :upload
      get    "/apps/:name/instances/:instance_id/files",   :files
      get    "/apps/:name/instances/:instance_id/files/*", :files
      get    "/apps/:name/stats",                          :stats
      get    "/apps/:name/instances",                      :instances
    end

    setup_routes
  end
end
