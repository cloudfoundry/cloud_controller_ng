require 'actions/v3/service_binding_delete'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingDelete < V3::ServiceBindingDelete
      private

      def perform_delete_actions(binding)
        binding.destroy
      end
    end
  end
end
