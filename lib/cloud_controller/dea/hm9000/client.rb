require 'set'

module VCAP::CloudController
  module Dea
    module HM9000
      class Client
        class UseDeprecatedNATSClient < StandardError; end

        MAX_RETRIES = 3

        def initialize(legacy_client, config)
          @legacy_client = legacy_client
          @config = config
        end

        def healthy_instances(app)
          healthy_instance_count(app, app_state_request(app))
        rescue UseDeprecatedNATSClient
          @legacy_client.healthy_instances(app)
        end

        def healthy_instances_bulk(apps)
          return {} if apps.nil? || apps.empty?

          response = app_state_bulk_request(apps)
          apps.each_with_object({}) do |app, result|
            result[app.guid] = healthy_instance_count(app, response[app.guid])
          end
        rescue UseDeprecatedNATSClient
          @legacy_client.healthy_instances_bulk(apps)
        end

        def find_crashes(app)
          response = app_state_request(app)
          return [] unless response

          response['instance_heartbeats'].each_with_object([]) do |instance, result|
            if instance['state'] == 'CRASHED'
              result << { 'instance' => instance['instance'], 'since' => instance['state_timestamp'] }
            end
          end
        rescue UseDeprecatedNATSClient
          @legacy_client.find_crashes(app)
        end

        def find_flapping_indices(app)
          response = app_state_request(app)
          return [] unless response

          response['crash_counts'].each_with_object([]) do |crash_count, result|
            if crash_count['crash_count'] >= @config[:flapping_crash_count_threshold]
              result << { 'index' => crash_count['instance_index'], 'since' => crash_count['created_at'] }
            end
          end
        rescue UseDeprecatedNATSClient
          @legacy_client.find_flapping_indices(app)
        end

        private

        def post_bulk_app_state(body, use_internal_address=true)
          uri = use_internal_address ? URI(@config[:hm9000][:internal_url]) : URI(@config[:hm9000][:url])
          uri.path = '/bulk_app_state'
          http_client.post(uri, body)
        end

        def http_client
          if !@http_client
            @http_client = HTTPClient.new
            username         = @config[:internal_api][:auth_user]
            password         = @config[:internal_api][:auth_password]
            skip_cert_verify = @config[:skip_cert_verify]

            if username && password
              @http_client.set_auth(nil, username, password)
            end
            @http_client.ssl_config.verify_mode = skip_cert_verify ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
            @http_client.ssl_config.set_default_paths
          end
          @http_client
        end

        def app_message(app)
          { droplet: app.guid, version: app.version }
        end

        def app_state_request(app)
          response = make_request([app_message(app)])
          return unless response.is_a?(Hash)
          response[app.guid]
        end

        def app_state_bulk_request(apps)
          make_request(apps.map { |app| app_message(app) })
        end

        def make_request(message)
          logger.info('requesting bulk_app_state', message: message)

          response = nil

          internal_address_errored = false

          (1..MAX_RETRIES).each do |i|
            begin
              response = post_bulk_app_state(message.to_json, true)
              if response.ok?
                break
              end
            rescue SocketError => se
              internal_address_errored = true
              logger.error('failed to connect to hm9000 via consul', { error: se.message })
              break
            end

            if i == MAX_RETRIES
              internal_address_errored = true
            end
          end

          response = post_bulk_app_state(message.to_json, false) if internal_address_errored
          raise UseDeprecatedNATSClient if response.status == 404

          if !response.ok?
            logger.info('received bulk_app_state failed', { message: message })
            return {}
          end

          responses = JSON.parse(response.body)

          logger.info('received bulk_app_state response', { message: message, responses: responses })
          responses
        end

        def healthy_instance_count(app, response)
          if response.nil? || response['instance_heartbeats'].nil?
            return -1
          end

          response['instance_heartbeats'].each_with_object(Set.new) do |heartbeats, result|
            if heartbeats['index'] < app.instances && (heartbeats['state'] == 'RUNNING' || heartbeats['state'] == 'STARTING')
              result.add(heartbeats['index'])
            end
          end.length
        end

        def logger
          @logger ||= Steno.logger('cc.healthmanager.client')
        end
      end
    end
  end
end
