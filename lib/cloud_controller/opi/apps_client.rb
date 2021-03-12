require 'uri'
require 'httpclient'
require 'multi_json'
require_relative '../../vcap/vars_builder'
require 'json'
require 'ostruct'
require 'cloud_controller/opi/helpers'
require 'cloud_controller/opi/base_client'

module OPI
  PROMETHEUS_PREFIX = 'prometheus.io'.freeze

  class Client < BaseClient
    def initialize(config, eirini_kube_client)
      super(config)
      @eirini_kube_client = eirini_kube_client
    end

    def desire_app(process)
      process_guid = process_guid(process)
      path = "/apps/#{process_guid}"
      @eirini_kube_client.create_lrp(desire_body(process))
    end

    def fetch_scheduling_infos
      path = '/apps'

      resp = client.get(path)
      resp_json = JSON.parse(resp.body)
      resp_json['desired_lrp_scheduling_infos'].map { |h| OPI.recursive_ostruct(h) }
    end

    def update_app(process, _)
      path = "/apps/#{process.guid}-#{process.version}"

      response = client.post(path, body: update_body(process))
      if response.status_code != 200
        response_json = OPI.recursive_ostruct(JSON.parse(response.body))
        raise CloudController::Errors::ApiError.new_from_details('RunnerError', response_json.error.message)
      end
      response
    end

    def get_app(process)
      path = "/apps/#{process.guid}/#{process.version}"

      response = client.get(path)
      if response.status_code == 404
        return nil
      end

      desired_lrp_response = OPI.recursive_ostruct(JSON.parse(response.body))
      desired_lrp_response.desired_lrp
    end

    def stop_app(versioned_guid)
      guid = VCAP::CloudController::Diego::ProcessGuid.cc_process_guid(versioned_guid)
      version = VCAP::CloudController::Diego::ProcessGuid.cc_process_version(versioned_guid)
      path = "/apps/#{guid}/#{version}/stop"
      client.put(path)
    end

    def stop_index(versioned_guid, index)
      guid = VCAP::CloudController::Diego::ProcessGuid.cc_process_guid(versioned_guid)
      version = VCAP::CloudController::Diego::ProcessGuid.cc_process_version(versioned_guid)
      path = "/apps/#{guid}/#{version}/stop/#{index}"
      client.put(path)
    end

    def bump_freshness; end

    private

    class DockerLifecycle
      def initialize(process)
        @process = process
      end

      def to_hash
        command = if @process.command.presence
                    ['/bin/sh', '-c', @process.command]
                  else
                    []
                  end
        {
          command: command,
          image: @process.desired_droplet.docker_receipt_image,
          registry_username: @process.desired_droplet.docker_receipt_username,
          registry_password: @process.desired_droplet.docker_receipt_password,
        }
      end
    end

    class KpackLifecycle
      CNB_LAUNCHER_PATH = '/cnb/lifecycle/launcher'.freeze

      def initialize(process)
        @process = process
      end

      def to_hash
        command = if @process.started_command.presence
                    [CNB_LAUNCHER_PATH.to_s, @process.started_command.to_s]
                  else
                    []
                  end
        {
          command: command,
          image: @process.desired_droplet.docker_receipt_image,
        }
      end
    end

    def lifecycle_for(process)
      case process.app.droplet.lifecycle_type
      when VCAP::CloudController::Lifecycles::DOCKER
        DockerLifecycle.new(process)
      when VCAP::CloudController::Lifecycles::KPACK
        KpackLifecycle.new(process)
      else
        raise("lifecycle type `#{process.app.lifecycle_type}` is invalid")
      end
    end

    def desire_body(process)
      timeout_ms = (process.health_check_timeout || 0) * 1000
      cpu_weight = VCAP::CloudController::Diego::TaskCpuWeightCalculator.new(memory_in_mb: process.memory).calculate
      lifecycle = lifecycle_for(process).to_hash
      lrp = Kubeclient::Resource.new({
        metadata: {
          name: process.app.name,
          namespace: @config.kubernetes_workloads_namespace,
        },
        spec: {
          GUID: process.guid,
          version: process.version,
          processType: process.type,
          appGUID: process.app.guid,
          appName: process.app.name,
          spaceGUID: process.space.guid,
          spaceName: process.space.name,
          orgGUID: process.organization.guid,
          orgName: process.organization.name,
          command: lifecycle[:command],
          image: lifecycle[:image],
          env: hash_values_to_s(environment_variables(process)),
          instances: process.desired_instances,
          memoryMB: process.memory,
          cpuWeight: cpu_weight,
          diskMB: process.disk_quota,
          health: {
            type: process.health_check_type,
            timeoutMs: timeout_ms,
          },
          lastUpdated: process.updated_at.to_f.to_s,
          volumeMounts: generate_volume_mounts(process),
          ports: process.open_ports,
          appRoutes: routes(process),
          userDefinedAnnotations: filter_annotations(process.app.annotations)
        }
      })
      lrp.spec.health.port = process.open_ports.first unless process.open_ports.empty?
      lrp.spec.health.endpoint = process.health_check_http_endpoint unless process.health_check_http_endpoint.nil?

      if !(lifecycle[:registry_username].to_s.empty? || lifecycle[:registry_password].to_s.empty?)
        lrp.spec.privateRegistry = {
          username: lifecycle[:registry_username],
          password: lifecycle[:registry_password],
        }
      end

      lrp
    end

    def filter_annotations(annotations)
      annotations.select { |anno| is_prometheus?(anno)
      }.map { |anno| ["#{anno.key_prefix}/#{anno.key}", anno.value] }.to_h
    end

    def is_prometheus?(anno)
      !anno.key_prefix.nil? && anno.key_prefix.start_with?(PROMETHEUS_PREFIX)
    end

    def health_check_timeout_in_seconds(process)
      process.health_check_timeout || config.get(:default_health_check_timeout)
    end

    def update_body(process)
      body = {
        guid: process.guid,
        version: process.version,
        update: {
          instances: process.desired_instances,
          routes: {"cf-router": routes(process)},
          annotation: process.updated_at.to_f.to_s
        }
      }
      MultiJson.dump(body)
    end

    def routes(process)
      routing_info = VCAP::CloudController::Diego::Protocol::RoutingInfo.new(process).routing_info
      (routing_info['http_routes'] || []).map do |i|
        {
          hostname: i['hostname'],
          port: i['port']
        }
      end
    end

    def environment_variables(process)
      initial_env = ::VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
      opi_env = initial_env.merge(process.environment_json || {}).
                merge('VCAP_APPLICATION' => vcap_application(process), 'MEMORY_LIMIT' => "#{process.memory}m").
                merge(SystemEnvPresenter.new(process.service_bindings).system_env)

      opi_env = opi_env.merge(DATABASE_URL: process.database_uri) if process.database_uri
      opi_env.merge(port_environment_variables(process))
    end

    def port_environment_variables(process)
      port = process.open_ports.first
      {
        PORT: port.to_s,
        VCAP_APP_PORT: port.to_s,
        VCAP_APP_HOST: '0.0.0.0'
      }
    end

    def vcap_application(process)
      VCAP::VarsBuilder.new(process).to_hash.reject do |k, _v|
        [:users].include? k
      end
    end

    def process_guid(process)
      "#{process.guid}-#{process.version}"
    end

    def generate_volume_mounts(process)
      app_volume_mounts = VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(process.app).as_json
      proto_volume_mounts = []

      app_volume_mounts.each do |volume_mount|
        if volume_mount['device']['mount_config'].present? && volume_mount['device']['mount_config']['name'].present?
          proto_volume_mount = {
            claimName: volume_mount['device']['mount_config']['name'],
            mountPath: volume_mount['container_dir']
          }
          proto_volume_mounts.append(proto_volume_mount)
        end
      end

      proto_volume_mounts
    end

    def logger
      @logger ||= Steno.logger('cc.opi.apps_client')
    end

    def hash_values_to_s(hash)
      Hash[hash.map do |k, v|
        case v
        when Array, Hash
          v = MultiJson.dump(v)
        else
          v = v.to_s
        end

        [k.to_s, v]
      end]
    end
  end
end
