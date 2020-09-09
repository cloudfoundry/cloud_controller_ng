module VCAP::CloudController
  module V3
    class ServiceCredentialBindingDelete
      class NotImplementedError < StandardError
      end

      def delete(binding)
        not_implemented! if binding.service_instance.managed_instance?
        binding.destroy
      end

      private

      def not_implemented!
        raise NotImplementedError.new
      end
    end
  end
end
