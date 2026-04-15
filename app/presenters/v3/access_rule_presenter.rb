require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class AccessRulePresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          {
            guid: access_rule.guid,
            created_at: access_rule.created_at,
            updated_at: access_rule.updated_at,
            selector: access_rule.selector,
            metadata: {
              labels: hashified_labels(access_rule.labels),
              annotations: hashified_annotations(access_rule.annotations)
            },
            relationships: build_relationships,
            links: build_links
          }
        end

        private

        def access_rule
          @resource
        end

        def build_relationships
          relationships = {
            route: {
              data: {
                guid: access_rule.route.guid
              }
            }
          }

          # Extract resource GUID from selector and populate read-only relationships
          selector_match = access_rule.selector.match(/\Acf:(app|space|org):([0-9a-f-]+)\z/)
          if selector_match
            resource_type = selector_match[1]
            resource_guid = selector_match[2]

            case resource_type
            when 'app'
              relationships[:app] = { data: { guid: resource_guid } }
              relationships[:space] = { data: nil }
              relationships[:organization] = { data: nil }
            when 'space'
              relationships[:app] = { data: nil }
              relationships[:space] = { data: { guid: resource_guid } }
              relationships[:organization] = { data: nil }
            when 'org'
              relationships[:app] = { data: nil }
              relationships[:space] = { data: nil }
              relationships[:organization] = { data: { guid: resource_guid } }
            end
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
              href: url_builder.build_url(path: "/v3/access_rules/#{access_rule.guid}")
            },
            route: {
              href: url_builder.build_url(path: "/v3/routes/#{access_rule.route.guid}")
            }
          }
        end
      end
    end
  end
end
