require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class RoutePolicyPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          hash = {
            guid: route_policy.guid,
            created_at: route_policy.created_at,
            updated_at: route_policy.updated_at,
            source: route_policy.source,
            metadata: {
              labels: hashified_labels(route_policy.labels),
              annotations: hashified_annotations(route_policy.annotations)
            },
            relationships: build_relationships,
            links: build_links
          }
          @decorators.reduce(hash) { |memo, d| d.decorate(memo, [route_policy]) }
        end

        private

        def route_policy
          @resource
        end

        def build_relationships
          relationships = {
            route: {
              data: {
                guid: route_policy.route.guid
              }
            }
          }

          # Extract resource GUID from source and populate read-only relationships
          # The guid is included as-is without per-row existence checks to avoid N+1 queries.
          # Use ?include=source to get full resource details with batch loading.
          source_match = route_policy.source.match(/\Acf:(app|space|org):([0-9a-f-]+)\z/)
          if source_match
            resource_type = source_match[1]
            resource_guid = source_match[2]

            relationships[:app] = { data: resource_type == 'app' ? { guid: resource_guid } : nil }
            relationships[:space] = { data: resource_type == 'space' ? { guid: resource_guid } : nil }
            relationships[:organization] = { data: resource_type == 'org' ? { guid: resource_guid } : nil }
          else
            # cf:any or malformed - all relationships are null
            relationships[:app] = { data: nil }
            relationships[:space] = { data: nil }
            relationships[:organization] = { data: nil }
          end

          relationships
        end

        def build_links
          {
            self: {
              href: url_builder.build_url(path: "/v3/route_policies/#{route_policy.guid}")
            },
            route: {
              href: url_builder.build_url(path: "/v3/routes/#{route_policy.route.guid}")
            }
          }
        end
      end
    end
  end
end
