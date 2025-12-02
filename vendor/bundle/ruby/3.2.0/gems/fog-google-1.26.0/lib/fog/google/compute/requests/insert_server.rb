module Fog
  module Google
    class Compute
      class Mock
        def insert_server(_instance_name, _zone, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def default_network_interface
          { :network => "global/networks/#{GOOGLE_COMPUTE_DEFAULT_NETWORK}" }
        end

        def process_disks(disks)
          unless disks && !disks.empty?
            raise ArgumentError.new("at least one value for disks is required")
          end

          disk_lst = disks.map do |d|
            d = d.attached_disk_obj if d.is_a? Disk
            ::Google::Apis::ComputeV1::AttachedDisk.new(**d)
          end
          disk_lst.first.boot = true
          disk_lst
        end

        def process_network_interfaces(network_interfaces)
          unless network_interfaces && !network_interfaces.empty?
            network_interfaces = [default_network_interface]
          end
          network_interfaces.map do |network|
            ::Google::Apis::ComputeV1::NetworkInterface.new(**network)
          end
        end

        ##
        # Create a new instance (virtual machine).
        #
        # This method allows you to use low-level request options and thus
        # expects instance options similar to API requests. If you don't need to
        # modify low-level request options, consider using the
        # Fog::Google::Compute::Servers collection object instead.
        #
        # @example minimal server creation
        #     my_operation = client.insert_server(
        #       "my-server",
        #       "us-central1-a",
        #       :machine_type => "f1-micro",
        #       :disks => [
        #         {
        #           :initialize_params => {
        #             :source_image => "projects/debian-cloud/global/images/family/debian-11"
        #           }
        #         }
        #       ]
        #     )
        #
        # @param instance_name [String]
        #   Name to assign to the created server. Must be unique within the specified zone.
        # @param zone [String]
        #   Name or URL of zone containing the created server.
        # @param options [Hash]
        #   Server attributes. You can use any of the options documented at
        #   https://cloud.google.com/compute/docs/reference/latest/instances/insert.
        # @see https://cloud.google.com/compute/docs/reference/latest/instances/insert
        # @return [::Google::Apis::ComputeV1::Operation]
        #   response object that represents the insertion operation.
        def insert_server(instance_name, zone, options = {})
          zone = zone.split("/")[-1]

          data = options.merge(:name => instance_name)
          data[:disks] = process_disks(options[:disks])
          data[:network_interfaces] = process_network_interfaces(options[:network_interfaces])

          machine_type = options[:machine_type]
          unless machine_type
            raise ArgumentError.new("machine type is required")
          end

          unless machine_type.include?("zones/")
            machine_type = "zones/#{zone}/machineTypes/#{data[:machine_type]}"
          end
          data[:machine_type] = machine_type

          # Optional subclassed attributes
          if data[:guest_accelerators]
            data[:guest_accelerators] = data[:guest_accelerators].map do |acc_config|
              ::Google::Apis::ComputeV1::AcceleratorConfig.new(**acc_config)
            end
          end

          if data[:metadata]
            data[:metadata] = ::Google::Apis::ComputeV1::Metadata.new(**options[:metadata])
          end

          if data[:scheduling]
            data[:scheduling] = ::Google::Apis::ComputeV1::Scheduling.new(**options[:scheduling])
          end

          if data[:shielded_instance_config]
            data[:shielded_instance_config] = ::Google::Apis::ComputeV1::ShieldedInstanceConfig.new(**options[:shielded_instance_config])
          end

          if data[:display_device]
            data[:display_device] = ::Google::Apis::ComputeV1::DisplayDevice.new(**options[:display_device])
          end

          if data[:tags]
            if options[:tags].is_a?(Array)
              # Process classic tag notation, i.e. ["fog"]
              data[:tags] = ::Google::Apis::ComputeV1::Tags.new(items: options[:tags])
            else
              data[:tags] = ::Google::Apis::ComputeV1::Tags.new(**options[:tags])
            end
          end

          instance = ::Google::Apis::ComputeV1::Instance.new(**data)
          @compute.insert_instance(@project, zone, instance)
        end
      end
    end
  end
end
