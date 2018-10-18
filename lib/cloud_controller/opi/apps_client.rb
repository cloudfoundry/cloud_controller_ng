require 'uri'
require 'httpclient'
require 'multi_json'
require_relative '../../vcap/vars_builder'
require 'json'
require 'ostruct'

module OPI
  class Client
    def initialize(opi_url)
      @client = HTTPClient.new(base_url: URI(opi_url))
    end

    def desire_app(process)
      process_guid = process_guid(process)
      path = "/apps/#{process_guid}"
      @client.put(path, body: desire_body(process))
    end

    def fetch_scheduling_infos
      path = '/apps'

      resp = @client.get(path)
      resp_json = JSON.parse(resp.body)
      resp_json['desired_lrp_scheduling_infos'].map { |h| recursive_ostruct(h) }
    end

    def update_app(process, _)
      path = "/apps/#{process.guid}"

      response = @client.post(path, body: update_body(process))
      if response.status_code != 200
        response_json = recursive_ostruct(JSON.parse(response.body))
        raise CloudController::Errors::ApiError.new_from_details('RunnerError', response_json.error.message)
      end
      response
    end

    def get_app(process)
      path = "/apps/#{process.guid}"

      response = @client.get(path)
      if response.status_code == 404
        return nil
      end

      desired_lrp_response = recursive_ostruct(JSON.parse(response.body))
      desired_lrp_response.desired_lrp
    end

    def stop_app(process_guid)
      path = "/apps/#{process_guid}/stop"
      @client.put(path)
    end

    def bump_freshness; end

    private

    def desire_body(process)
      timeout_ms = (process.health_check_timeout || 0) * 1000

      body = {
        process_guid: process_guid(process),
        docker_image: process.current_droplet.docker_receipt_image,
        start_command: process.specified_or_detected_command,
        environment: hash_values_to_s(vcap_application(process)),
        instances: process.desired_instances,
        droplet_hash: process.current_droplet.droplet_hash,
        droplet_guid: process.current_droplet.guid,
        health_check_type: process.health_check_type,
        health_check_http_endpoint: process.health_check_http_endpoint,
        health_check_timeout_ms: timeout_ms,
        last_updated: process.updated_at.to_f.to_s
      }
      MultiJson.dump(body)
    end

    def update_body(process)
      body = {
        process_guid: process.guid,
        update: {
          instances: process.desired_instances,
          routes: routes(process),
          annotation: process.updated_at.to_f.to_s
        }
      }
      MultiJson.dump(body)
    end

    def routes(process)
      routing_info = VCAP::CloudController::Diego::Protocol::RoutingInfo.new(process).routing_info
      http_routes = (routing_info['http_routes'] || []).map do |i|
        {
          hostnames:         [i['hostname']],
          port:              i['port']
        }
      end

      { 'cf-router' => http_routes }
    end

    def recursive_ostruct(hash)
      OpenStruct.new(hash.map { |key, value|
        new_val = value.is_a?(Hash) ? recursive_ostruct(value) : value
        [key, new_val]
      }.to_h)
    end

    def vcap_application(process)
      process.environment_json.merge(VCAP_APPLICATION: VCAP::VarsBuilder.new(process).to_hash)
    end

    def process_guid(process)
      "#{process.guid}-#{process.version}"
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
