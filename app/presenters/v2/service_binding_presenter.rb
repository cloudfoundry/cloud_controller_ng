module CloudController
  module Presenters
    module V2
      class ServiceBindingPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ServiceBinding'

        def entity_hash(controller, service_binding, opts, depth, parents, orphans=nil)
          rel_hash = RelationsPresenter.new.to_hash(controller, service_binding, opts, depth, parents, orphans)
          rel_hash['service_binding_parameters_url'] = "/v2/service_bindings/#{service_binding.guid}/parameters"

          {
            'app_guid'              => service_binding.app_guid,
            'service_instance_guid' => service_binding.service_instance_guid,
            'credentials'           => redact_creds_if_necessary(service_binding),
            'binding_options'       => {},
            'gateway_data'          => nil,
            'gateway_name'          => '',
            'syslog_drain_url'      => service_binding.syslog_drain_url,
            'volume_mounts'         => ::ServiceBindingPresenter.censor_volume_mounts(service_binding.volume_mounts),
            'name'                  => service_binding.name,
          }.merge!(rel_hash)
        end

        private

        def redact_creds_if_necessary(binding)
          access_context = VCAP::CloudController::Security::AccessContext.new

          return binding.credentials if access_context.can?(:read_env, binding)
          { 'redacted_message' => VCAP::CloudController::Presenters::V3::BasePresenter::REDACTED_MESSAGE }
        end
      end
    end
  end
end
