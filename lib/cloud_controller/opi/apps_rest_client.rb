require 'uri'
require 'httpclient'
require 'multi_json'
require_relative '../../vcap/vars_builder'
require 'json'
require 'ostruct'
require 'cloud_controller/opi/helpers'
require 'cloud_controller/opi/base_client'

module OPI
  class Client < BaseClient
    def desire_app(process)
      process_guid = OPI.process_guid(process)
      path = "/apps/#{process_guid}"
      client.put(path, body: desire_body(process))
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

    def desire_body(process)
      timeout_ms = (process.health_check_timeout || 0) * 1000
      cpu_weight = VCAP::CloudController::Diego::TaskCpuWeightCalculator.new(memory_in_mb: process.memory).calculate
      lifecycle = OPI.lifecycle_for(process)
      body = {
        guid: process.guid,
        version: process.version,
        process_guid: OPI.process_guid(process),
        process_type: process.type,
        app_guid: process.app_guid,
        app_name: process.app.name,
        space_guid: process.space.guid,
        space_name: process.space.name,
        organization_guid: process.organization.guid,
        organization_name: process.organization.name,
        environment: OPI.hash_values_to_s(OPI.environment_variables(process)),
        egress_rules: VCAP::CloudController::Diego::EgressRules.new.running_protobuf_rules(process),
        placement_tags: Array(VCAP::CloudController::IsolationSegmentSelector.for_space(process.space)),
        instances: process.desired_instances,
        memory_mb: process.memory,
        disk_mb: process.disk_quota,
        cpu_weight: cpu_weight,
        health_check_type: process.health_check_type,
        health_check_http_endpoint: process.health_check_http_endpoint,
        health_check_timeout_ms: timeout_ms,
        start_timeout_ms: health_check_timeout_in_seconds(process) * 1000,
        last_updated: process.updated_at.to_f.to_s,
        volume_mounts: generate_volume_mounts(process),
        ports: process.open_ports,
        routes: { 'cf-router': OPI.routes(process) },
        lifecycle: lifecycle.to_hash,
        user_defined_annotations: OPI.filter_annotations(process.app.annotations)
      }
      MultiJson.dump(body)
    end

    def update_body(process)
      body = {
        guid: process.guid,
        version: process.version,
        update: {
          instances: process.desired_instances,
          routes: { 'cf-router': OPI.routes(process) },
          annotation: process.updated_at.to_f.to_s
        }
      }
      MultiJson.dump(body)
    end

    def generate_volume_mounts(process)
      app_volume_mounts = VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(process.app).as_json
      proto_volume_mounts = []

      app_volume_mounts.each do |volume_mount|
        if volume_mount['device']['mount_config'].present? && volume_mount['device']['mount_config']['name'].present?
          proto_volume_mount = {
            volume_id: volume_mount['device']['mount_config']['name'],
            mount_dir: volume_mount['container_dir']
          }
          proto_volume_mounts.append(proto_volume_mount)
        end
      end

      proto_volume_mounts
    end

    def logger
      @logger ||= Steno.logger('cc.opi.apps_rest_client')
    end

    def health_check_timeout_in_seconds(process)
      process.health_check_timeout || config.get(:default_health_check_timeout)
    end
  end
end
