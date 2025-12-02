module Fog
  module OpenStack
    class DNS < Fog::Service
      autoload :V1, 'fog/openstack/dns/v1'
      autoload :V2, 'fog/openstack/dns/v2'

      # Fog::OpenStack::DNS.new() will return a Fog::OpenStack::DNS::V2 or a Fog::OpenStack::DNS::V1,
      # choosing the latest available
      def self.new(args = {})
        @openstack_auth_uri = URI.parse(args[:openstack_auth_url]) if args[:openstack_auth_url]
        if inspect == 'Fog::OpenStack::DNS'
          service = Fog::OpenStack::DNS::V2.new(args) unless args.empty?
          service ||= Fog::OpenStack::DNS::V1.new(args)
        else
          service = Fog::Service.new(args)
        end
        service
      end
    end
  end
end
