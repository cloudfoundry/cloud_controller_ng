require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceCredentialBindingPresenter < BasePresenter
          def to_hash
            {
              guid: @resource.guid,
              type: @resource.type
            }
          end
        end
      end
    end
  end
end
