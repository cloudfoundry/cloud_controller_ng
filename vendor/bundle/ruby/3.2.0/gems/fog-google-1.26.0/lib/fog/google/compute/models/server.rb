require "fog/compute/models/server"

module Fog
  module Google
    class Compute
      class Server < Fog::Compute::Server
        identity :name

        # @return [Boolean]
        attribute :can_ip_forward, :aliases => "canIpForward"

        # @return [String]
        attribute :cpu_platform, :aliases => "cpuPlatform"

        # @return [String]
        attribute :creation_timestamp, :aliases => "creationTimestamp"

        # @return [Boolean]
        attribute :deletion_protection, :aliases => "deletionProtection"

        # @return [String]
        attribute :description

        # New disks may include :initialize_params before save.
        #
        # @example Minimal disks pre-creation:
        #   [
        #     {
        #       :initialize_params => {
        #         :source_image => "projects/debian-cloud/global/images/family/debian-11"
        #       }
        #     }
        #   ]
        #
        # @example disks post-creation:
        #   [
        #     {
        #       :auto_delete => false,
        #       :boot => true,
        #       :device_name => "persistent-disk-0",
        #       :index => 0,
        #       :interface => "SCSI",
        #       :kind => "compute#attachedDisk",
        #       :licenses => ["https://www.googleapis.com/compute/v1/..."],
        #       :mode => "READ_WRITE",
        #       :source => "https://www.googleapis.com/compute/v1/.../mydisk",
        #       :type => "PERSISTENT"
        #     }
        #   ]
        # @return [Array<Hash>]
        attribute :disks

        # @example Enable the display device
        #   {
        #     :enable_display => true
        #   }
        # @return [Hash<String,Boolean>]
        attribute :display_device, :aliases => "displayDevice"

        # @example Guest accelerators
        #   [
        #     {
        #       :accelerator_count => 1,
        #       :accelerator_type => "...my/accelerator/type"
        #     }
        #   ]
        # @return [Array<Hash>]
        attribute :guest_accelerators, :aliases => "guestAccelerators"

        # @return [Fixnum]
        attribute :id

        # @return [String]
        attribute :kind

        # @return [String]
        attribute :label_fingerprint, :aliases => "labelFingerprint"

        # @return [Hash<String,String>]
        attribute :labels

        # @return [String]
        attribute :machine_type, :aliases => "machineType"

        # If set initially before save, the expected format
        # is the API format as shown below.
        #
        # If you want to pass in a Hash, see {#set_metadata}.
        # If you want to access the metadata items as a Hash, see
        # {#metadata_as_h}.
        #
        # @example Metadata in API format
        #
        #   {
        #     :fingerprint => "...",
        #     :items => [
        #       { :key => "foo", :value => "bar" },
        #     ]
        #   }
        # @return [Hash]
        attribute :metadata

        # @return [String]
        attribute :min_cpu_platform, :aliases => "minCpuPlatform"

        # @example Network interfaces
        #   [
        #     {
        #       :kind => "compute#networkInterface",
        #       :name => "nic0",
        #       :network => "https://www.googleapis.com/compute/v1/.../my-network/"
        #       :network_ip => "0.0.0.0",
        #       :subnetwork => "https://www.googleapis.com/compute/v1/.../my-subnetwork"
        #     }
        #   ],
        # @return [Array<Hash>]
        attribute :network_interfaces, :aliases => "networkInterfaces"

        # @example Scheduling object
        # {
        #   :automatic_restart => true,
        #   :on_host_maintenance => "MIGRATE",
        #   :preemptible=>false
        # }
        # @return [Hash]
        attribute :scheduling

        # @return [String]
        attribute :self_link, :aliases => "selfLink"

        # @example Service accounts in API format
        # [
        #   {
        #     :email => "my-service-account@developer.gserviceaccount.com",
        #     :scopes => [],
        #   }
        # ]
        # @return [Array<Hash>]
        attribute :service_accounts, :aliases => "serviceAccounts"

        # @return [Boolean]
        attribute :start_restricted, :aliases => "startRestricted"

        # @return [String]
        attribute :status, :aliases => "status"

        # @return [String]
        attribute :status_message, :aliases => "statusMessage"

        # @example Tags in API format
        # @return [Hash]
        attribute :tags

        # @return [String]
        attribute :zone, :aliases => :zone_name

        GCE_SCOPE_ALIASES = {
          "default" => %w(
            https://www.googleapis.com/auth/cloud.useraccounts.readonly
            https://www.googleapis.com/auth/devstorage.read_only
            https://www.googleapis.com/auth/logging.write
            https://www.googleapis.com/auth/monitoring.write
            https://www.googleapis.com/auth/pubsub
            https://www.googleapis.com/auth/service.management.readonly
            https://www.googleapis.com/auth/servicecontrol
            https://www.googleapis.com/auth/trace.append
          ),
          "bigquery" => ["https://www.googleapis.com/auth/bigquery"],
          "cloud-platform" => ["https://www.googleapis.com/auth/cloud-platform"],
          "compute-ro" => ["https://www.googleapis.com/auth/compute.readonly"],
          "compute-rw" => ["https://www.googleapis.com/auth/compute"],
          "datastore" => ["https://www.googleapis.com/auth/datastore"],
          "logging-write" => ["https://www.googleapis.com/auth/logging.write"],
          "monitoring" => ["https://www.googleapis.com/auth/monitoring"],
          "monitoring-write" => ["https://www.googleapis.com/auth/monitoring.write"],
          "service-control" => ["https://www.googleapis.com/auth/servicecontrol"],
          "service-management" => ["https://www.googleapis.com/auth/service.management.readonly"],
          "sql" => ["https://www.googleapis.com/auth/sqlservice"],
          "sql-admin" => ["https://www.googleapis.com/auth/sqlservice.admin"],
          "storage-full" => ["https://www.googleapis.com/auth/devstorage.full_control"],
          "storage-ro" => ["https://www.googleapis.com/auth/devstorage.read_only"],
          "storage-rw" => ["https://www.googleapis.com/auth/devstorage.read_write"],
          "taskqueue" => ["https://www.googleapis.com/auth/taskqueue"],
          "useraccounts-ro" => ["https://www.googleapis.com/auth/cloud.useraccounts.readonly"],
          "useraccounts-rw" => ["https://www.googleapis.com/auth/cloud.useraccounts"],
          "userinfo-email" => ["https://www.googleapis.com/auth/userinfo.email"]
        }.freeze

        # Return the source image of the server's boot disk
        #
        # @return [String] image self link
        def image_name
          boot_disk = disks.first
          unless boot_disk.is_a?(Disk)
            source = boot_disk[:source]
            match = source.match(%r{/zones/(.*)/disks/(.*)$})
            boot_disk = service.disks.get(match[2], match[1])
          end
          boot_disk.source_image.nil? ? nil : boot_disk.source_image
        end

        # Destroy a server.
        #
        # @param async [TrueClass] execute the command asynchronously
        # @return [Fog::Google::Compute::Operation]
        def destroy(async = true)
          requires :name, :zone

          data = service.delete_server(name, zone_name)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          operation
        end

        # Helper method that returns first public ip address needed for
        # Fog::Compute::Server.ssh default behavior.
        #
        # @return [String]
        def public_ip_address
          public_ip_addresses.first
        end

        # Helper method that returns all of server's public ip addresses.
        #
        # @return [Array]
        def public_ip_addresses
          addresses = []
          if network_interfaces.respond_to? :flat_map
            addresses = network_interfaces.flat_map do |nic|
              if nic[:access_configs].respond_to? :each
                nic[:access_configs].select { |config| config[:name] == "External NAT" }
                                    .map { |config| config[:nat_ip] }
              else
                []
              end
            end
          end
          addresses
        end

        # Helper method that returns the first private ip address of the
        # instance.
        #
        # @return [String]
        def private_ip_address
          private_ip_addresses.first
        end

        # Helper method that returns all of server's private ip addresses.
        #
        # @return [Array]
        def private_ip_addresses
          addresses = []
          if network_interfaces.respond_to? :map
            addresses = network_interfaces.map { |nic| nic[:network_ip] }
          end
          addresses
        end

        # Helper method that returns all of server's ip addresses,
        # both private and public.
        #
        # @return [Array]
        def addresses
          private_ip_addresses + public_ip_addresses
        end

        # Attach a disk to a running server
        #
        # @param disk [Object, String] disk object or a self-link
        # @param async [TrueClass] execute the api call asynchronously
        # @param options [Hash]
        # @return [Object]
        def attach_disk(disk, async = true, attached_disk_options = {})
          requires :identity, :zone

          if disk.is_a? Disk
            disk_obj = disk.attached_disk_obj(**attached_disk_options)
          elsif disk.is_a? String
            disk_obj = service.disks.attached_disk_obj(disk, **attached_disk_options)
          end

          data = service.attach_disk(identity, zone_name, disk_obj)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        # Detach disk from a running instance
        #
        # @param device_name [Object]
        # @param async [TrueClass]
        # @returns [Fog::Google::Compute::Server] server object
        def detach_disk(device_name, async = true)
          requires :identity, :zone

          data = service.detach_disk(identity, zone, device_name)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        # Returns metadata items as a Hash.
        #
        # @return [Hash<String, String>] items
        def metadata_as_h
          if metadata.nil? || metadata[:items].nil? || metadata[:items].empty?
            return {}
          end

          Hash[metadata[:items].map { |item| [item[:key], item[:value]] }]
        end

        def reboot(async = true)
          requires :identity, :zone

          data = service.reset_server(identity, zone_name)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          operation
        end

        def start(async = true)
          requires :identity, :zone

          data = service.start_server(identity, zone_name)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          operation
        end

        def stop(async = true, discard_local_ssd=false)
          requires :identity, :zone

          data = service.stop_server(identity, zone_name, discard_local_ssd)
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          operation
        end

        def serial_port_output(port: 1)
          requires :identity, :zone

          service.get_server_serial_port_output(identity, zone_name, :port => port).to_h[:contents]
        end

        def set_disk_auto_delete(auto_delete, device_name = nil, async = true)
          requires :identity, :zone

          if device_name.nil? && disks.count > 1
            raise ArgumentError.new("Device name is required if multiple disks are attached")
          end

          device_name ||= disks.first[:device_name]
          data = service.set_server_disk_auto_delete(
            identity, zone_name, auto_delete, device_name
          )

          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        def set_scheduling(async = true,
                           on_host_maintenance: nil,
                           automatic_restart: nil,
                           preemptible: nil)
          requires :identity, :zone
          data = service.set_server_scheduling(
            identity, zone_name,
            :on_host_maintenance => on_host_maintenance,
            :automatic_restart => automatic_restart,
            :preemptible => preemptible
          )

          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        # Set an instance metadata
        #
        # @param [Bool] async Perform the operation asyncronously
        # @param [Hash] new_metadata A new metadata object
        #   Format: {'foo' => 'bar', 'baz'=>'foo'}
        #
        # @returns [Fog::Google::Compute::Server] server object
        def set_metadata(new_metadata = {}, async = true)
          requires :identity, :zone

          unless new_metadata.is_a?(Hash)
            raise Fog::Errors::Error.new("Instance metadata should be a hash")
          end

          # If metadata is presented in {'foo' => 'bar', 'baz'=>'foo'}
          new_metadata_items = new_metadata.each.map { |k, v| { :key => k.to_s, :value => v.to_s } }

          data = service.set_server_metadata(
            identity, zone_name, metadata[:fingerprint], new_metadata_items
          )
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        def set_machine_type(new_machine_type, async = true)
          requires :identity, :zone

          raise Fog::Errors::Error.new("Instance must be stopped to change machine type") unless stopped?

          data = service.set_server_machine_type(
            identity, zone_name, new_machine_type
          )
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        def set_tags(new_tags = [], async = true)
          requires :identity, :zone

          data = service.set_server_tags(
            identity, zone_name, tags[:fingerprint], new_tags
          )
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        # Check if instance is provisioning. On staging vs. provisioning difference:
        # https://cloud.google.com/compute/docs/instances/checking-instance-status
        #
        # @return [TrueClass or FalseClass]
        def provisioning?
          status == "PROVISIONING"
        end

        # Check if instance is staging. On staging vs. provisioning difference:
        # https://cloud.google.com/compute/docs/instances/checking-instance-status
        #
        # @return [TrueClass or FalseClass]
        def staging?
          status == "STAGING"
        end

        # Check if instance is stopped.
        #
        # @return [TrueClass or FalseClass]
        def stopped?
          status == "TERMINATED"
        end

        # Check if instance is ready.
        #
        # @return [TrueClass or FalseClass]
        def ready?
          status == "RUNNING"
        end

        def zone_name
          zone.nil? ? nil : zone.split("/")[-1]
        end

        def add_ssh_key(username, key, async = true)
          metadata = generate_ssh_key_metadata(username, key)

          data = service.set_server_metadata(
            identity, zone_name, metadata[:fingerprint], metadata[:items]
          )

          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          reload
        end

        def reload
          data = service.get_server(name, zone_name).to_h
          merge_attributes(data)
        end

        def map_scopes(scopes)
          return [] if scopes.nil?
          scopes.flat_map do |scope|
            if GCE_SCOPE_ALIASES.key? scope
              # Expand scope alias to list of related scopes
              GCE_SCOPE_ALIASES[scope]
            else
              [scope_url(scope)]
            end
          end
        end

        def save(username: nil, public_key: nil)
          requires :name
          requires :machine_type
          requires :disks
          requires :zone

          generate_ssh_key_metadata(self.username, self.public_key) if self.public_key

          # XXX HACK This is a relic of 1.0 change that for some reason added those arguments
          # to `save` method. This is left in place to keep things backwards-compatible
          # TODO(2.0): Remove arguments from save
          generate_ssh_key_metadata(username, public_key) if public_key

          options = attributes.reject { |_, v| v.nil? }

          if service_accounts && service_accounts[0]
            service_accounts[0][:scopes] = map_scopes(service_accounts[0][:scopes])
            options[:service_accounts] = service_accounts
          end

          if attributes[:external_ip]
            if options[:network_interfaces].nil? || options[:network_interfaces].empty?
              options[:network_interfaces] = [
                {
                  :network => "global/networks/#{GOOGLE_COMPUTE_DEFAULT_NETWORK}"
                }
              ]
            end

            # Add external IP as default access config if given
            options[:network_interfaces][0][:access_configs] = [
              {
                :name => "External NAT",
                :type => "ONE_TO_ONE_NAT",
                :nat_ip => attributes[:external_ip]
              }
            ]
          end

          if attributes[:network_ip]
            options[:network_interfaces][0][:network_ip] = attributes[:network_ip]
          end

          data = service.insert_server(name, zone_name, options)

          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? }
          reload
        end

        def generate_ssh_key_metadata(username, key)
          if metadata.nil?
            self.metadata = Hash.new
          end
          metadata[:items] = [] if metadata[:items].nil?
          metadata_map = Hash[metadata[:items].map { |item| [item[:key], item[:value]] }]

          ssh_keys = metadata_map["ssh-keys"] || metadata_map["sshKeys"] || ""
          ssh_keys += "\n" unless ssh_keys.empty?
          ssh_keys += "#{username}:#{ensure_key_comment(key, username)}"

          metadata_map["ssh-keys"] = ssh_keys
          metadata[:items] = metadata_to_item_list(metadata_map)
          metadata
        end

        def ensure_key_comment(key, default_comment = "fog-user")
          parts = key.strip.split
          parts << default_comment if parts.size < 3
          parts.join(" ")
        end

        def reset_windows_password(user)
          service.reset_windows_password(:server => self, :user => user)
        end

        private

        def metadata_to_item_list(metadata)
          metadata.map { |k, v| { :key => k, :value => v } }
        end

        def scope_url(scope)
          if scope.start_with?("https://")
            scope
          else
            "https://www.googleapis.com/auth/#{scope}"
          end
        end
      end
    end
  end
end
