module Fog
  module Google
    class Compute
      class HttpHealthCheck < Fog::Model
        identity :name

        attribute :check_interval_sec, :aliases => "checkIntervalSec"
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :healthy_threshold, :aliases => "healthyThreshold"
        attribute :host
        attribute :id
        attribute :kind
        attribute :port
        attribute :request_path, :aliases => "requestPath"
        attribute :self_link, :aliases => "selfLink"
        attribute :timeout_sec, :aliases => "timeoutSec"
        attribute :unhealthy_threshold, :aliases => "unhealthyThreshold"

        MODIFIABLE_FIELDS = %i(
          name
          check_interval_sec
          creation_timestamp
          description
          healthy_threshold
          host
          port
          request_path
          timeout_sec
          unhealthy_threshold
        ).freeze

        def save
          opts = {
            :name => name,
            :check_interval_sec => check_interval_sec,
            :creation_timestamp => creation_timestamp,
            :description => description,
            :healthy_threshold => healthy_threshold,
            :host => host,
            :port => port,
            :request_path => request_path,
            :timeout_sec => timeout_sec,
            :unhealthy_threshold => unhealthy_threshold
          }

          id.nil? ? create(opts) : update(opts)
        end

        def create(opts)
          requires :name

          data = service.insert_http_health_check(name, opts)
          operation = Fog::Google::Compute::Operations.new(service: service)
                                                      .get(data.name, data.zone)
          operation.wait_for { ready? }
          reload
        end

        def update(opts)
          requires :name
          data = service.update_http_health_check(name, opts)
          operation = Fog::Google::Compute::Operations.new(service: service)
                                                      .get(data.name, data.zone)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :name
          data = service.delete_http_health_check(name)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def ready?
          service.get_http_health_check(name)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def reload
          requires :name

          return unless data = begin
            collection.get(name)
          rescue Excon::Errors::SocketError
            nil
          end

          new_attributes = data.attributes
          merge_attributes(new_attributes)
          self
        end

        RUNNING_STATE = "READY".freeze
      end
    end
  end
end
