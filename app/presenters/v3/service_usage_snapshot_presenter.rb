require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceUsageSnapshotPresenter < BasePresenter
        def to_hash
          {
            guid: snapshot.guid,
            created_at: snapshot.created_at,
            completed_at: snapshot.completed_at,
            checkpoint_event_guid: snapshot.checkpoint_event_guid,
            checkpoint_event_created_at: snapshot.checkpoint_event_created_at,
            summary: {
              service_instance_count: snapshot.service_instance_count,
              organization_count: snapshot.organization_count,
              space_count: snapshot.space_count,
              chunk_count: snapshot.chunk_count
            },
            links: build_links
          }
        end

        private

        def snapshot
          @resource
        end

        def build_links
          links = {
            self: { href: url_builder.build_url(path: "/v3/service_usage/snapshots/#{snapshot.guid}") }
          }

          links[:checkpoint_event] = { href: url_builder.build_url(path: "/v3/service_usage_events/#{snapshot.checkpoint_event_guid}") } if snapshot.checkpoint_event_guid.present?

          links[:chunks] = { href: url_builder.build_url(path: "/v3/service_usage/snapshots/#{snapshot.guid}/chunks") } if snapshot.complete?

          links
        end
      end
    end
  end
end
