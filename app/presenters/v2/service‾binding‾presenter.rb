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
            'last_operation'        => {
              'type'        => service_binding.last_operation.try(:type) || 'create',
              'state'       => service_binding.last_operation.try(:state) || 'succeeded',
              'description' => service_binding.last_operation.try(:description) || '',
              'updated_at'  => service_binding.last_operation.try(:updated_at) || service_binding.updated_at,
              'created_at'  => service_binding.last_operation.try(:created_at) || service_binding.created_at,
            },
          }.merge!(rel_hash)
        end
      end
    end
  end
end
