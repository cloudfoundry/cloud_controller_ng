

module Fog
  module OpenStack
    class Image < Fog::Service
      autoload :V1, 'fog/openstack/image/v1'
      autoload :V2, 'fog/openstack/image/v2'

      # Fog::OpenStack::Image.new() will return a Fog::OpenStack::Image::V2 or a Fog::OpenStack::Image::V1,
      #  choosing the latest available
      def self.new(args = {})
        @openstack_auth_uri = URI.parse(args[:openstack_auth_url]) if args[:openstack_auth_url]
        if inspect == 'Fog::OpenStack::Image'
          service = Fog::OpenStack::Image::V2.new(args) unless args.empty?
          service ||= Fog::OpenStack::Image::V1.new(args)
        else
          service = Fog::Service.new(args)
        end
        service
      end
    end
  end
end
