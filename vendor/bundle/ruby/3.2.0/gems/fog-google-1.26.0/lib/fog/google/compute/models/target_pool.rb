module Fog
  module Google
    class Compute
      class TargetPool < Fog::Model
        identity :name

        attribute :backup_pool, :aliases => "backupPool"
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :failover_ratio, :aliases => "failoverRatio"
        attribute :health_checks, :aliases => "healthChecks"
        attribute :id
        attribute :instances
        attribute :kind
        attribute :region
        attribute :self_link, :aliases => "selfLink"
        attribute :session_affinity, :aliases => "sessionAffinity"

        def save
          requires :name, :region

          data = service.insert_target_pool(
            name, region, attributes.reject { |_k, v| v.nil? }
          )
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity, :region
          data = service.delete_target_pool(identity, region)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async
          operation
        end

        def add_instance(instance, async = true)
          requires :identity
          instance = instance.self_link unless instance.class == String
          data = service.add_target_pool_instances(identity, region, [instance])
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async

          reload
        end

        def remove_instance(instance, async = true)
          requires :identity

          instance = instance.self_link unless instance.class == String
          data = service.remove_target_pool_instances(identity, region, [instance])
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)

          operation.wait_for { ready? } unless async

          reload
        end

        def add_health_check(health_check, async = true)
          requires :identity, :region

          health_check = health_check.self_link unless health_check.class == String
          data = service.add_target_pool_health_checks(identity, region, [health_check])
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async

          reload
        end

        def remove_health_check(health_check, async = true)
          requires :identity, :region

          health_check = health_check.self_link unless health_check.class == String
          data = service.remove_target_pool_health_checks(identity, region, [health_check])
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async
          reload
        end

        ##
        # Get most recent health checks for each IP for instances.
        #
        # @param [String] instance_name a specific instance to look up. Default
        #   behavior returns health checks for all instances associated with
        #   this check.
        # @returns [Hash<String, Array<Hash>>] a map of instance URL to health checks
        #
        # Example Hash:
        # {
        #   "https://www.googleapis.com/compute/v1/projects/myproject/zones/us-central1-f/instances/myinstance"=>
        # [{:health_state=>"UNHEALTHY",
        #   :instance=>"https://www.googleapis.com/compute/v1/projects/myproject/zones/us-central1-f/instances/myinstance"
        # }]
        # }
        #
        def get_health(instance_name = nil)
          requires :identity, :region

          if instance_name
            instance = service.servers.get(instance_name)
            data = service.get_target_pool_health(identity, region, instance.self_link)
                          .to_h[:health_status] || []
            results = [[instance.self_link, data]]
          else
            results = instances.map do |self_link|
              # TODO: Improve the returned object, current is hard to navigate
              # [{instance => @instance, health_state => "HEALTHY"}, ...]
              data = service.get_target_pool_health(identity, region, self_link)
                            .to_h[:health_status] || []
              [self_link, data]
            end
          end
          Hash[results]
        end

        def set_backup(backup = nil)
          requires :identity, :region

          backup ||= backup_pool

          service.set_target_pool_backup(
            identity, region, backup,
            :failover_ratio => failover_ratio
          )
          reload
        end

        def ready?
          service.get_target_pool(name, region)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def region_name
          region.nil? ? nil : region.split("/")[-1]
        end

        def reload
          requires :name, :region

          return unless data = begin
            collection.get(name, region)
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
