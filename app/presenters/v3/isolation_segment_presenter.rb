require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class IsolationSegmentPresenter < BasePresenter
        def to_hash
          {
            guid: label.guid,
            name: label.name,
            created_at: label.created_at,
            updated_at: label.updated_at
          }
        end

        private

        def label
          @resource
        end
      end
    end
  end
end
