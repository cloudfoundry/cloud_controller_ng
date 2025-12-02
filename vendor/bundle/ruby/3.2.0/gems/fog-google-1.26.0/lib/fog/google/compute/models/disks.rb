module Fog
  module Google
    class Compute
      class Disks < Fog::Collection
        model Fog::Google::Compute::Disk

        def all(zone: nil, filter: nil, max_results: nil, order_by: nil,
                page_token: nil)
          opts = {
            :filter => filter,
            :max_results => max_results,
            :order_by => order_by,
            :page_token => page_token
          }
          items = []
          next_page_token = nil
          loop do
            if zone
              data = service.list_disks(zone, **opts)
              next_items = data.items || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_aggregated_disks(**opts)
              data.items.each_value do |scoped_list|
                items.concat(scoped_list.disks) if scoped_list && scoped_list.disks
              end
              next_page_token = data.next_page_token
            end
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items.map(&:to_h))
        end

        def get(identity, zone = nil)
          if zone
            disk = service.get_disk(identity, zone).to_h

            # Force the hash to contain a :users key so that it will override any :users key in the existing object
            disk[:users] = nil unless disk.include?(:users)

            return new(disk)
          elsif identity
            response = all(:filter => "name eq #{identity}",
                           :max_results => 1)
            disk = response.first unless response.empty?
            return disk
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          # Return an empty object so that wait_for processes the block
          return new({:status => nil})
        end

        # Returns an attached disk configuration hash.
        #
        # Compute API needs attached disks to be specified in a custom format.
        # This provides a handy shortcut for generating a preformatted config.
        #
        # Example output:
        # {:auto_delete=>false,
        #  :boot=>true,
        #  :mode=>"READ_WRITE",
        #  :source=>"https://www.googleapis.com/compute/v1/projects/myproj/zones/us-central1-f/disks/mydisk",
        #  :type=>"PERSISTENT"}
        #
        # See Instances.insert API docs for more info:
        # https://cloud.google.com/compute/docs/reference/rest/v1/instances/insert
        #
        # @param [String]  source  self_link of an existing disk resource
        # @param [Boolean]  writable  The mode in which to attach this disk.
        #   (defaults to READ_WRITE)
        # @param [Boolean]  boot  Indicates whether this is a boot disk.
        #   (defaults to false)
        # @param [String]  device_name  Specifies a unique device name of your
        #   choice that is reflected into the /dev/disk/by-id/google-* tree of
        #   a Linux operating system running within the instance.
        # @param [Object]  encryption_key  Encrypts or decrypts a disk using
        #   a customer-supplied encryption key.
        # @param [Object]  auto_delete  Specifies whether the disk will be
        #   auto-deleted when the instance is deleted. (defaults to false)
        # @return [Hash]
        def attached_disk_obj(source,
                              writable: true,
                              boot: false,
                              device_name: nil,
                              encryption_key: nil,
                              auto_delete: false)
          {
            :auto_delete => auto_delete,
            :boot => boot,
            :device_name => device_name,
            :disk_encryption_key => encryption_key,
            :mode => writable ? "READ_WRITE" : "READ_ONLY",
            :source => source,
            :type => "PERSISTENT"
          }.reject { |_k, v| v.nil? }
        end
      end
    end
  end
end
