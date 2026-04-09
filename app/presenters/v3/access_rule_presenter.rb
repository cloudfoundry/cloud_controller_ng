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
            name: access_rule.name,
            selector: access_rule.selector,
            relationships: {
              route: {
                data: {
                  guid: access_rule.route.guid
                }
              }
            },
            links: build_links
          }
        end

        private

        def access_rule
          @resource
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
