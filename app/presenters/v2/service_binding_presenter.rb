module CloudController
  module Presenters
    module V2
      class ServiceBindingPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ServiceBinding'

        def entity_hash(controller, service_binding, opts, depth, parents, orphans=nil)
          {
            'app_guid'              => service_binding.app_guid,
            'service_instance_guid' => service_binding.service_instance_guid,
            'credentials'           => redact_creds_if_necessary(service_binding),
            'binding_options'       => {},
            'gateway_data'          => nil,
            'gateway_name'          => '',
            'syslog_drain_url'      => service_binding.syslog_drain_url,
            'volume_mounts'         => ::ServiceBindingPresenter.censor_volume_mounts(service_binding.volume_mounts)
          }.merge!(RelationsPresenter.new.to_hash(controller, service_binding, opts, depth, parents, orphans))
        end

        private

        def redact_creds_if_necessary(binding)
          admin_override           = VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
          admin_or_space_developer = admin_override || binding.space.has_developer?(VCAP::CloudController::SecurityContext.current_user)

          return binding.credentials if admin_or_space_developer
          { 'redacted_message' => VCAP::CloudController::Presenters::V3::BasePresenter::REDACTED_MESSAGE }
        end
      end
    end
  end
end
