require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class SharedSpacesUsageSummaryPresenter < BasePresenter
        def to_hash
          {
            usage_summary: build_usage_summary,
            links: build_links
          }
        end

        private

        def service_instance
          @resource
        end

        def build_usage_summary
          count = Hash.new(0).tap do |h|
            service_instance.service_bindings.each do |binding|
              h[binding.app.space_guid] += 1
            end
          end

          service_instance.shared_spaces.sort_by(&:id).map do |space|
            {
              space: { guid: space.guid },
              bound_app_count: count[space.guid]
            }
          end
        end

        def build_links
          {
            self: {
              href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces/usage_summary")
            },
            shared_spaces: {
              href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces")
            },
            service_instance: {
              href: url_builder.build_url(path: "/v3/service_instances/#{service_instance.guid}")
            }
          }
        end
      end
    end
  end
end
