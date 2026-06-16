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

          if route_policy.source_type == 'any'
            relationships[:app]          = { data: nil }
            relationships[:space]        = { data: nil }
            relationships[:organization] = { data: nil }
          else
            relationships[:app]          = { data: route_policy.source_type == 'app'   ? { guid: route_policy.source_guid } : nil }
            relationships[:space]        = { data: route_policy.source_type == 'space' ? { guid: route_policy.source_guid } : nil }
            relationships[:organization] = { data: route_policy.source_type == 'org'   ? { guid: route_policy.source_guid } : nil }
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
