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
          # Only include the guid in data if the resource actually exists
          selector_match = access_rule.selector.match(/\Acf:(app|space|org):([0-9a-f-]+)\z/)
          if selector_match
            resource_type = selector_match[1]
            resource_guid = selector_match[2]

            case resource_type
            when 'app'
              app_exists = VCAP::CloudController::AppModel.where(guid: resource_guid).any?
              relationships[:app] = { data: app_exists ? { guid: resource_guid } : nil }
              relationships[:space] = { data: nil }
              relationships[:organization] = { data: nil }
            when 'space'
              space_exists = VCAP::CloudController::Space.where(guid: resource_guid).any?
              relationships[:app] = { data: nil }
              relationships[:space] = { data: space_exists ? { guid: resource_guid } : nil }
              relationships[:organization] = { data: nil }
            when 'org'
              org_exists = VCAP::CloudController::Organization.where(guid: resource_guid).any?
              relationships[:app] = { data: nil }
              relationships[:space] = { data: nil }
              relationships[:organization] = { data: org_exists ? { guid: resource_guid } : nil }
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
