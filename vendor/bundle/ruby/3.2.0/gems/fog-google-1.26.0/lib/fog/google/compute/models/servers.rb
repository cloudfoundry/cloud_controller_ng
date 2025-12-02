module Fog
  module Google
    class Compute
      class Servers < Fog::Collection
        model Fog::Google::Compute::Server

        def all(zone: nil, filter: nil, max_results: nil,
                order_by: nil, page_token: nil)
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
              data = service.list_servers(zone, **opts)
              next_items = data.to_h[:items] || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_aggregated_servers(**opts)
              data.items.each_value do |scoped_lst|
                if scoped_lst && scoped_lst.instances
                  items.concat(scoped_lst.instances.map(&:to_h))
                end
              end
              next_page_token = data.next_page_token
            end

            break if next_page_token.nil? || next_page_token.empty?

            opts[:page_token] = next_page_token
          end

          load(items)
        end

        # TODO: This method needs to take self_links as well as names
        def get(identity, zone = nil)
          if zone
            server = service.get_server(identity, zone).to_h
            return new(server)
          elsif identity
            response = all(:filter => "name eq .*#{identity}",
                           :max_results => 1)
            server = response.first unless response.empty?
            return server
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end

        def bootstrap(public_key_path: nil, **opts)
          name = "fog-#{Time.now.to_i}"
          zone_name = "us-central1-f"

          disks = opts[:disks]

          if disks.nil? || disks.empty?
            # create the persistent boot disk
            source_img = service.images.get_from_family("debian-11")
            disk_defaults = {
              :name => name,
              :size_gb => 10,
              :zone_name => zone_name,
              :source_image => source_img.self_link
            }
            disk = service.disks.create(**disk_defaults.merge(opts))
            disk.wait_for { disk.ready? }

            disks = [disk]
          end

          # TODO: Remove the network init when #360 is fixed
          network = { :network => "global/networks/default",
                      :access_configs => [{ :name => "External NAT",
                                            :type => "ONE_TO_ONE_NAT" }] }

          # Merge the options with the defaults, overwriting defaults
          # if an option is provided
          data = { :name => name,
                   :zone => zone_name,
                   :disks => disks,
                   :network_interfaces => [network],
                   :public_key => get_public_key(public_key_path),
                   :username => ENV["USER"] }.merge(opts)

          data[:machine_type] = "n1-standard-1" unless data[:machine_type]

          server = new(data)
          server.save
          server.wait_for { ready? }

          # Set the disk to be autodeleted
          # true - autodelete setting
          # nil - device name (not needed if there's only one disk)
          # false - set async to false so set the property synchronously
          server.set_disk_auto_delete(true, nil, false)

          server
        end

        private

        # Defaults to:
        # 1. ~/.ssh/google_compute_engine.pub
        # 2. ~/.ssh/id_rsa.pub
        PUBLIC_KEY_DEFAULTS = %w(
          ~/.ssh/google_compute_engine.pub
          ~/.ssh/id_rsa.pub
        ).freeze
        def get_public_key(public_key_path)
          unless public_key_path
            PUBLIC_KEY_DEFAULTS.each do |path|
              if File.exist?(File.expand_path(path))
                public_key_path = path
                break
              end
            end
          end

          if public_key_path.nil? || public_key_path.empty?
            raise Fog::Errors::Error.new("Cannot bootstrap instance without a public key")
          end

          File.read(File.expand_path(public_key_path))
        end
      end
    end
  end
end
