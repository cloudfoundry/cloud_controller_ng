require "cloud_controller/diego/desire_request"
require "cloud_controller/diego/staging_request"
require "cloud_controller/diego/unavailable"
require "cloud_controller/diego/environment"

module VCAP::CloudController
  module Diego
    class Client
      def initialize(enabled, message_bus, service_registry, blobstore_url_generator)
        @enabled = enabled
        @message_bus = message_bus
        @service_registry = service_registry
        @blobstore_url_generator = blobstore_url_generator
        @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
      end

      def connect!
        @service_registry.run!
      end

      def running_enabled?(app)
        @enabled && (app.environment_json || {})["CF_DIEGO_RUN_BETA"] == "true"
      end

      def staging_enabled?(app)
        return false unless @enabled
        running_enabled?(app) || ((app.environment_json || {})["CF_DIEGO_BETA"] == "true")
      end

      def send_desire_request(app)
        logger.info("desire.app.begin", :app_guid => app.guid)
        @message_bus.publish("diego.desire.app", desire_request(app).to_json)
      end

      def send_stage_request(app, staging_task_id)
        app.update(staging_task_id: staging_task_id)

        logger.info("staging.begin", :app_guid => app.guid)

        staging_request = StagingRequest.new(app, @blobstore_url_generator, @buildpack_entry_generator)
        @message_bus.publish("diego.staging.start", staging_request.as_json)
      end

      def desire_request(app)
        DesireRequest.new(app, @blobstore_url_generator)
      end

      def lrp_instances(app)
        if @service_registry.tps_addrs.empty?
          raise Unavailable
        end

        address = @service_registry.tps_addrs.first
        guid = app.versioned_guid

        uri = URI("#{address}/lrps/#{guid}")
        logger.info "Requesting lrp information for #{guid} from #{address}"

        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        http.open_timeout = 10

        response = http.get(uri.path)
        raise Unavailable.new unless response.code == '200'

        logger.info "Received lrp response for #{guid}: #{response.body}"

        result = []

        tps_instances = JSON.parse(response.body)
        tps_instances.each do |instance|
          result << {
            process_guid: instance['process_guid'],
            instance_guid: instance['instance_guid'],
            index: instance['index'],
            state: instance['state'].upcase,
            since: instance['since_in_ns'].to_i / 1_000_000_000,
          }
        end

        logger.info "Returning lrp instances for #{guid}: #{result.inspect}"

        result
      rescue Errno::ECONNREFUSED => e
        raise Unavailable.new(e)
      end

      private

      def logger
        @logger ||= Steno.logger("cc.diego.client")
      end
    end
  end
end
