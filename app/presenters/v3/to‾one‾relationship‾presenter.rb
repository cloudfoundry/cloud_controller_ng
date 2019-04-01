module VCAP::CloudController
  module Presenters
    module V3
      class ToOneRelationshipPresenter
        def initialize(resource_path:, related_instance:, relationship_name:, related_resource_name:)
          @resource_path = resource_path
          @related_instance = related_instance
          @relationship_name = relationship_name
          @related_resource_name = related_resource_name
        end

        def to_hash
          {
            data: build_relation,
            links: build_links
          }
        end

        private

        attr_reader :resource_path, :relationship_name, :related_instance, :related_resource_name

        def url_builder
          @url_builder ||= VCAP::CloudController::Presenters::ApiUrlBuilder.new
        end

        def build_relation
          { guid: related_instance.guid } unless related_instance.nil?
        end

        def build_links
          {
            self: { href: self_link }
          }.tap do |links|
            links[:related] = { href: related_link } if related_instance
          end
        end

        def self_link
          url_builder.build_url(path: "/v3/#{resource_path}/relationships/#{relationship_name}")
        end

        def related_link
          url_builder.build_url(path: "/v3/#{related_resource_name}/#{related_instance.guid}")
        end
      end
    end
  end
end
