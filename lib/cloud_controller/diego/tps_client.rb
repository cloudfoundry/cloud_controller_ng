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
        http_client.read_timeout = 30
        http_client.open_timeout = 15
        http_client
      end

      def fetch_lrp_status(guid)
        logger.info('lrp.instances.status', process_guid: guid)

        path = "/v1/actual_lrps/#{guid}"
        fetch_from_tps(path, {})
      end

      def fetch_lrp_stats(guid)
        logger.info('lrp.instances.stats', process_guid: guid)

        path = "/v1/actual_lrps/#{guid}/stats"
        headers = { 'Authorization' => VCAP::CloudController::SecurityContext.auth_token }
        fetch_from_tps(path, headers)
      end

      def fetch_from_tps(path, headers)
        if @url.nil?
          raise Errors::InstancesUnavailable.new('TPS URL not configured')
        end

        response = nil
        tries = 5

        begin
          response = http_client.get2(path, headers)
        rescue Errno::ECONNREFUSED, Net::ReadTimeout, Net::OpenTimeout => e
          tries -= 1
          logger.debug('Connection problem', error_message: e.to_s, tries: tries, path: path)
          retry unless tries == 0
          raise Errors::InstancesUnavailable.new(e)
        end

        if response.code != '200'
          err_msg = "response code: #{response.code}, response body: #{response.body}"
          raise Errors::InstancesUnavailable.new(err_msg)
        end

        JSON.parse(response.body, symbolize_names: true)
      rescue JSON::JSONError => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def logger
        @logger ||= Steno.logger('cc.tps.client')
      end
    end
  end
end
