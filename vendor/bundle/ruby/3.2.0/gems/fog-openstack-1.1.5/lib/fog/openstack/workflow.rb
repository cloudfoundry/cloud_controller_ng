module Fog
  module OpenStack
    class Workflow < Fog::Service
      autoload :V2, 'fog/openstack/workflow/v2'

      # Fog::OpenStack::Workflow.new() will return a Fog::OpenStack::Workflow::V2
      #  Will choose the latest available once Mistral V3 is released.
      def self.new(args = {})
        @openstack_auth_uri = URI.parse(args[:openstack_auth_url]) if args[:openstack_auth_url]
        Fog::OpenStack::Workflow::V2.new(args)
      end
    end
  end
end
