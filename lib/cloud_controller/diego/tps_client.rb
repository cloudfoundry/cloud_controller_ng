require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  module Diego
    class TPSClient
      def initialize(config)
        @url = URI(config[:diego_tps_url]) if config[:diego_tps_url]
      end

      def lrp_instances(app)
        guid = ProcessGuid.from_app(app)
        fetch_lrp_instances(guid, "#{@tps_url}/v1/actual_lrps/#{guid}")
      end

      def lrp_instances_stats(app)
        guid = ProcessGuid.from_app(app)
        headers = { 'Authorization' => VCAP::CloudController::SecurityContext.auth_token }
        fetch_lrp_instances(guid, "#{@tps_url}/v1/actual_lrps/#{guid}/stats", headers)
      end

      private

      def http_client
        http_client = Net::HTTP.new(@url.host, @url.port)
        http_client.read_timeout = 10
        http_client.open_timeout = 10
        http_client
      end

      def fetch_lrp_instances(guid, path, headers=nil)
        if @url.nil?
          raise Errors::InstancesUnavailable.new('invalid config')
        end

        logger.info('lrp.instances', process_guid: guid)

        begin
          tries ||= 3
          response = http_client.get2(path, headers)
        rescue Errno::ECONNREFUSED => e
          retry unless (tries -= 1).zero?
          raise Errors::InstancesUnavailable.new(e)
        end

        raise Errors::InstancesUnavailable.new("response code: #{response.code}") unless response.code == '200'

        logger.info('lrp.instances.response', process_guid: guid, response_code: response.code)

        result = []

        tps_instances = JSON.parse(response.body)
        tps_instances.each do |instance|
          info = {
            process_guid: instance['process_guid'],
            instance_guid: instance['instance_guid'],
            index: instance['index'],
            state: instance['state'].upcase,
            since: instance['since_in_ns'].to_i / 1_000_000_000,
          }
          info[:details] = instance['details'] if instance['details']
          info[:stats] = instance['stats'] || {}
          result << info
        end

        result
      end

      def logger
        @logger ||= Steno.logger('cc.tps.client')
      end
    end
  end
end
