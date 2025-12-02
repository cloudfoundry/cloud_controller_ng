require 'fog/openstack/models/model'
require 'fog/openstack/storage/models/files'

module Fog
  module OpenStack
    class Storage
      class Directory < Fog::OpenStack::Model
        identity  :key, :aliases => 'name'

        attribute :bytes, :aliases => 'X-Container-Bytes-Used'
        attribute :count, :aliases => 'X-Container-Object-Count'

        attr_writer :public

        def destroy
          requires :key
          service.delete_container(key)
          true
        rescue Excon::Errors::NotFound
          false
        end

        def files
          @files ||= begin
            Fog::OpenStack::Storage::Files.new(
              :directory => self,
              :service   => service
            )
          end
        end

        def public_url
          requires :key

          @public_url ||= begin
            service.public_url(key)
          rescue Fog::OpenStack::Storage::NotFound => err
            nil
          end
        end

        def save
          requires :key
          service.put_container(key, :public => @public)
          true
        end
      end
    end
  end
end
