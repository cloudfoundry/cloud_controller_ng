require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceUsageSnapshotChunkPresenter < BasePresenter
        def to_hash
          {
            organization_guid: chunk.organization_guid,
            organization_name: chunk.organization_name,
            space_guid: chunk.space_guid,
            space_name: chunk.space_name,
            chunk_index: chunk.chunk_index,
            service_instances: chunk.service_instances || []
          }
        end

        private

        def chunk
          @resource
        end
      end
    end
  end
end
