require 'presenters/v3/base_presenter'
require 'models/helpers/label_helpers'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceBrokerPresenter < BasePresenter
        def to_hash
          {
            guid: broker.guid,
            name: broker.name,
            url: broker.broker_url,
            created_at: broker.created_at,
            updated_at: broker.updated_at,
            relationships: build_relationships,
            links: build_links,
          }
        end

        private

        def broker
          @resource
        end

        def build_relationships
          if broker.space_guid.nil?
            {}
          else
            {
              space: {
                data: {
                  guid: broker.space_guid
                }
              }
            }
          end
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
          links = {
            self: {
              href: url_builder.build_url(path: "/v3/service_brokers/#{broker.guid}")
            }
          }

          if broker.space_guid
            links[:space] = { href: url_builder.build_url(path: "/v3/spaces/#{broker.space_guid}") }
          end

          links
        end
      end
    end
  end
end
