module CloudController
  module Presenters
    module V2
      class ServiceKeyPresenter < DefaultPresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ServiceKey'

        def entity_hash(controller, service_key, opts, depth, parents, orphans=nil)
          default_hash = super(controller, service_key, opts, depth, parents, orphans)
          default_hash.merge!({
            'service_key_parameters_url' => "/v2/service_keys/#{service_key.guid}/parameters",
            'credentials' => redact_creds_if_necessary(service_key),
          })
        end
      end
    end
  end
end
