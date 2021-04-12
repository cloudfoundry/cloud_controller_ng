require 'uri'
require 'httpclient'
require 'multi_json'
require_relative '../../vcap/vars_builder'
require 'json'
require 'ostruct'
require 'cloud_controller/opi/helpers'
require 'cloud_controller/opi/base_client'

module OPI
  class KubernetesClient < BaseClient
    def initialize(config, eirini_kube_client, apps_rest_client)
      super(config)
      @eirini_kube_client = eirini_kube_client
      @apps_rest_client = apps_rest_client
    end

    def desire_app(process)
      @eirini_kube_client.create_lrp(desire_body(process))
    end

    def fetch_scheduling_infos
      @apps_rest_client.fetch_scheduling_infos
    end

    def update_app(process, existing_lrp)
      @apps_rest_client.update_app(process, existing_lrp)
    end

    def get_app(process)
      @apps_rest_client.get_app(process)
    end

    def stop_app(versioned_guid)
      @apps_rest_client.stop_app(versioned_guid)
    end

    def stop_index(versioned_guid, index)
      @apps_rest_client.stop_index(versioned_guid, index)
    end

    def bump_freshness; end

    private

    def desire_body(process)
      timeout_ms = (process.health_check_timeout || 0) * 1000
      cpu_weight = VCAP::CloudController::Diego::TaskCpuWeightCalculator.new(memory_in_mb: process.memory).calculate
      lifecycle = OPI.lifecycle_for(process).to_hash
      lrp = Kubeclient::Resource.new(
        {
          metadata: {
            name: process.app.name,
            namespace: @config.kubernetes_workloads_namespace
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
            command: lifecycle[:docker_lifecycle][:command],
            image: lifecycle[:docker_lifecycle][:image],
            env: OPI.hash_values_to_s(OPI.environment_variables(process)),
            instances: process.desired_instances,
            memoryMB: process.memory,
            cpuWeight: cpu_weight,
            diskMB: process.disk_quota,
            health: {
              type: process.health_check_type,
              timeoutMs: timeout_ms
            },
            lastUpdated: process.updated_at.to_f.to_s,
            volumeMounts: generate_volume_mounts(process),
            ports: process.open_ports,
            appRoutes: OPI.routes(process),
            userDefinedAnnotations: OPI.filter_annotations(process.app.annotations)
          }
        }
      )
      lrp.spec.health.port = process.open_ports.first unless process.open_ports.empty?
      lrp.spec.health.endpoint = process.health_check_http_endpoint unless process.health_check_http_endpoint.nil?

      unless lifecycle[:docker_lifecycle][:registry_username].to_s.empty? || lifecycle[:docker_lifecycle][:registry_password].to_s.empty?
        lrp.spec.privateRegistry = {
          username: lifecycle[:docker_lifecycle][:registry_username],
          password: lifecycle[:docker_lifecycle][:registry_password]
        }
      end

      lrp
    end

    def generate_volume_mounts(process)
      app_volume_mounts = VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(process.app).as_json
      proto_volume_mounts = []

      app_volume_mounts.each do |volume_mount|
        unless volume_mount['device']['mount_config'].present? && volume_mount['device']['mount_config']['name'].present?
          next
        end

        proto_volume_mount = {
          claimName: volume_mount['device']['mount_config']['name'],
          mountPath: volume_mount['container_dir']
        }
        proto_volume_mounts.append(proto_volume_mount)
      end

      proto_volume_mounts
    end

    def logger
      @logger ||= Steno.logger('cc.opi.apps_client')
    end
  end
end
