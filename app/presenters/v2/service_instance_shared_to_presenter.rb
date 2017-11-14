require 'presenters/v2/service_instance_shared_from_presenter'

module CloudController
  module Presenters
    module V2
      class ServiceInstanceSharedToPresenter < ServiceInstanceSharedFromPresenter
        def to_hash(space)
          super(space)
        end
      end
    end
  end
end
