module Fog
  module Google
    class Compute
      class InstanceGroup < Fog::Model
        identity :name

        attribute :id
        attribute :kind
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :fingerprint
        attribute :namedPorts
        attribute :network
        attribute :subnetwork
        attribute :self_link, :aliases => "selfLink"
        attribute :size
        attribute :zone, :aliases => :zone_name

        def save
          requires :name, :zone

          options = {
            "network" => network_name,
            "subnetwork" => subnetwork_name
          }

          service.insert_instance_group(name, zone, options)
        end

        def destroy(_async = true)
          requires :name, :zone

          service.delete_instance_group(name, zone_name)
        end

        def add_instance(instance_id)
          add_instances [instance_id]
        end

        def add_instances(instances)
          requires :identity, :zone

          service.add_instance_group_instances(
            identity, zone_name, format_instance_list(instances)
          )
        end

        def remove_instances(instances)
          requires :identity, :zone

          service.remove_instance_group_instances(
            identity, zone_name, format_instance_list(instances)
          )
        end

        def list_instances
          requires :identity, :zone

          instance_list = []
          data = service.list_instance_group_instances(identity, zone_name)
          if data.items
            data.items.each do |instance|
              instance_list << service.servers.get(instance.instance.split("/")[-1], zone_name)
            end
          end
          instance_list
        end

        def zone_name
          zone.nil? ? nil : zone.split("/")[-1]
        end

        def network_name
          network.nil? ? nil : network.split("/")[-1]
        end

        def subnetwork_name
          subnetwork.nil? ? nil : subnetwork.split("/")[-1]
        end

        private

        def format_instance_list(instance_list)
          instance_list = Array(instance_list)
          instance_list.map { |i| i.class == String ? i : i.self_link }
        end
      end
    end
  end
end
