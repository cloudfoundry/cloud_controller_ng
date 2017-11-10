require 'presenters/v2/service_instance_shared_from_presenter'

module CloudController
  module Presenters
    module V2
      class ServiceInstanceSharedToPresenter < ServiceInstanceSharedFromPresenter
        def to_hash(space, bound_app_count)
          super(space).merge({ 'bound_app_count' => bound_app_count })
        end
      end
    end
  end
end
