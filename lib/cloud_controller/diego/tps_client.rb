require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  module Diego
    class TPSClient
      def initialize(config)
        url = URI(config[:diego_tps_url] || '')
        if url.host && url.port
          @http_client = Net::HTTP.new(url.host, url.port)
          @http_client.read_timeout = 10
          @http_client.open_timeout = 10
        end
      end

      def lrp_instances(app)
        if @http_client.nil?
          raise Errors::InstancesUnavailable.new('invalid config')
        end

        guid = ProcessGuid.from_app(app)

        path = "#{@tps_url}/lrps/#{guid}"
        logger.info('lrp.instances', process_guid: guid)

        begin
          tries ||= 3
          response = @http_client.get(path)
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
          result << info
        end

        result
      end

      private

      def logger
        @logger ||= Steno.logger('cc.tps.client')
      end
    end
  end
end
