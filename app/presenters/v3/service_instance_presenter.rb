require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceInstancePresenter < BasePresenter
        def to_hash
          {
            guid:       service_instance.guid,
            created_at: service_instance.created_at,
            updated_at: service_instance.updated_at,
            name:      service_instance.name,
            relationships: {
              space: {
                data: {
                  guid: service_instance.space.guid
                }
              }
            },
            links: {
              space: {
                href: url_builder.build_url(path: "/v3/spaces/#{service_instance.space.guid}")
              }
            }
          }
        end

        private

        def url_builder
          VCAP::CloudController::Presenters::ApiUrlBuilder.new
        end

        def service_instance
          @resource
        end
      end
    end
  end
end
