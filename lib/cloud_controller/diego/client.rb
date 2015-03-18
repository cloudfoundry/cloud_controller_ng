require 'cloud_controller/diego/unavailable'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  module Diego
    class Client
      def initialize(config)
        @tps_url = config[:diego_tps_url]
      end

      def lrp_instances(app)
        if @tps_url.nil?
          raise Unavailable
        end

        guid = ProcessGuid.from_app(app)

        uri = URI("#{@tps_url}/lrps/#{guid}")
        logger.info "Requesting lrp information for #{guid} from #{@tps_url}"


        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        http.open_timeout = 10

        begin
          tries ||= 3
          response = http.get(uri.path)
        rescue Errno::ECONNREFUSED => e
          retry unless(tries -= 1).zero?
          raise Unavailable.new(e)
        end

        raise Unavailable.new unless response.code == '200'

        logger.info "Received lrp response for #{guid}: #{response.body}"

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

        logger.info "Returning lrp instances for #{guid}: #{result.inspect}"

        result
      end

      private

      def logger
        @logger ||= Steno.logger('cc.diego.client')
      end
    end
  end
end
