module VCAP::CloudController
  module V3
    class ServiceCredentialBindingCreate
      class UnprocessableCreate < StandardError
      end

      def initialize(user_audit_info)
        @user_audit_info = user_audit_info
      end

      def precursor(service_instance, app: nil, name: nil)
        not_supported! unless service_instance.user_provided_instance?
        app_is_required! unless app.present?
        space_mismatch! unless app.space.guid == service_instance.space.guid

        binding_details = {
          service_instance: service_instance,
          name: name,
          app: app,
          type: 'app',
          credentials: {}
        }

        ServiceBinding.new(**binding_details).tap do |b|
          b.save_with_new_operation(
            {
              type: 'create',
              state: 'in progress',
            }
          )
        end
      rescue Sequel::ValidationFailed => e
        already_bound! if e.message =~ /The app is already bound to the service/
        raise UnprocessableCreate.new(e.full_message)
      end

      def bind(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.bind(binding, arbitrary_parameters: {}, accepts_incomplete: false)

        binding.save_with_new_operation({ type: 'create', state: 'succeeded' }, attributes: details[:binding])

        event_repository.record_create(binding, @user_audit_info, manifest_triggered: false)
      rescue => e
        binding.save_with_new_operation({
          type: 'create',
          state: 'failed',
          description: e.message,
        })
        raise e
      end

      private

      def event_repository
        Repositories::ServiceBindingEventRepository
      end

      def app_is_required!
        raise UnprocessableCreate.new('No app was specified')
      end

      def not_supported!
        raise UnprocessableCreate.new('Cannot create credential bindings for managed service instances')
      end

      def already_bound!
        raise UnprocessableCreate.new('The app is already bound to the service instance')
      end

      def space_mismatch!
        raise UnprocessableCreate.new('The service instance and the app are in different spaces')
      end
    end
  end
end
