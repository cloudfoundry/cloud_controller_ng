require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class SidecarPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          {
            guid: sidecar.guid,
            name: sidecar.name,
            command: sidecar.command,
            process_types: sidecar.process_types,
            memory_in_mb: sidecar.memory,
            origin: sidecar.origin,
            relationships: {
              app: {
                data: {
                  guid: sidecar.app_guid,
                },
              },
            },
            created_at: sidecar.created_at,
            updated_at: sidecar.updated_at,
          }
        end

        private

        def sidecar
          @resource
        end
      end
    end
  end
end
