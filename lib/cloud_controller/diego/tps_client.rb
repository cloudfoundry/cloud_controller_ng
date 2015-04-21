require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  module Diego
    class TPSClient
      def initialize(config)
        @url = URI(config[:diego_tps_url]) if config[:diego_tps_url]
      end

      def lrp_instances(app)
        guid = ProcessGuid.from_app(app)
        fetch_lrp_status(guid)
      end

      def lrp_instances_stats(app)
        guid = ProcessGuid.from_app(app)
        fetch_lrp_stats(guid)
      end

      private

      def http_client
        http_client = Net::HTTP.new(@url.host, @url.port)
        http_client.read_timeout = 10
        http_client.open_timeout = 10
        http_client
      end

      def fetch_lrp_status(guid)
        logger.info('lrp.instances.status', process_guid: guid)

        path = "/v1/actual_lrps/#{guid}"
        tps_instances = fetch_from_tps(path, {})

        result = []

        tps_instances.each do |instance|
          info = build_cc_instance(instance)
          result << info
        end

        result
      end

      def fetch_lrp_stats(guid)
        logger.info('lrp.instances.stats', process_guid: guid)

        path = "/v1/actual_lrps/#{guid}/stats"
        headers = { 'Authorization' => VCAP::CloudController::SecurityContext.auth_token }
        tps_instances = fetch_from_tps(path, headers)

        result = []

        tps_instances.each do |instance|
          info = build_cc_instance(instance)
          info[:stats] = instance['stats'] || {}
          result << info
        end

        result
      end

      def fetch_from_tps(path, headers)
        if @url.nil?
          raise Errors::InstancesUnavailable.new('TPS URL not configured')
        end

        response = nil
        tries = 3

        begin
          response = http_client.get2(path, headers)
        rescue Errno::ECONNREFUSED => e
          tries -= 1
          retry unless tries == 0
          raise Errors::InstancesUnavailable.new(e)
        end

        if response.code != '200'
          err_msg = "response code: #{response.code}, response body: #{response.body}"
          raise Errors::InstancesUnavailable.new(err_msg)
        end

        JSON.parse(response.body)
      rescue JSON::JSONError => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def build_cc_instance(instance)
        info = {
          process_guid: instance['process_guid'],
          instance_guid: instance['instance_guid'],
          index: instance['index'],
          state: instance['state'].upcase,
          since: instance['since_in_ns'].to_i / 1_000_000_000,
        }
        info[:details] = instance['details'] if instance['details']
        info
      end

      def logger
        @logger ||= Steno.logger('cc.tps.client')
      end
    end
  end
end
