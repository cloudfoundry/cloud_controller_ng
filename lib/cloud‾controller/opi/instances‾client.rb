require 'httpclient'
require 'json'
require 'cloud_controller/errors/instances_unavailable'
require 'cloud_controller/errors/no_running_instances'

module OPI
  class InstancesClient
    ActualLRPKey = Struct.new(:index, :process_guid)
    ActualLRPNetInfo = Struct.new(:address, :ports)
    PortMapping = Struct.new(:container_port, :host_port)
    DesiredLRP = Struct.new(:PlacementTags, :metric_tags)

    class ActualLRPNetInfo
      def to_hash
        to_h
      end
    end

    class ActualLRP
      attr_reader :actual_lrp_key
      attr_reader :state
      attr_reader :since
      attr_reader :placement_error
      attr_reader :actual_lrp_net_info

      def initialize(instance, process_guid)
        @actual_lrp_key = ActualLRPKey.new(instance['index'], process_guid)
        @state = instance['state']
        @since = instance['since']
        @placement_error = instance['placement_error']
        @actual_lrp_net_info = ActualLRPNetInfo.new('127.0.0.1', Array[PortMapping.new(8080, 80)])
      end

      def ==(other)
        other.class == self.class && other.actual_lrp_key == @actual_lrp_key
      end
    end

    def initialize(opi_url)
      @client = HTTPClient.new(base_url: URI(opi_url))
    end

    def lrp_instances(process)
      path = "/apps/#{process.guid}/#{process.version}/instances"
      begin
        retries ||= 0
        resp = @client.get(path)
        resp_json = JSON.parse(resp.body)
        handle_error(resp_json)
      rescue CloudController::Errors::NoRunningInstances => e
        sleep(1)
        retry if (retries += 1) < 5
        raise e
      end
      process_guid = resp_json['process_guid']
      resp_json['instances'].map do |instance|
        ActualLRP.new(instance, process_guid)
      end
    end

    # Currently opi does not support isolation segments. This stub is necessary
    # because cc relies that at least one placement tag will be available
    def desired_lrp_instance(process)
      DesiredLRP.new(['placeholder'], { "process_id": 0 })
    end

    private

    def handle_error(response_body)
      error = response_body['error']
      return unless error

      raise CloudController::Errors::NoRunningInstances.new('No running instances')
    end
  end
end
