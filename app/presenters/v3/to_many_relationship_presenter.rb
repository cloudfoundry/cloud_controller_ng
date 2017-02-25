module VCAP::CloudController
  module Presenters
    module V3
      class ToManyRelationshipPresenter
        def initialize(relation_url, relationships, relationship_path, build_related: true)
          @relation_url = relation_url
          @relationships = relationships
          @relationship_path = relationship_path
          @build_related = build_related
        end

        def to_hash
          {
            data: build_relations,
            links: build_links
          }
        end

        private

        def url_builder
          VCAP::CloudController::Presenters::ApiUrlBuilder.new
        end

        def build_relations
          data = []

          @relationships.each do |relationship|
            data << { guid: relationship.guid }
          end

          data
        end

        def build_links
          links = {
            self: { href: url_builder.build_url(path: "/v3/#{@relation_url}/relationships/#{@relationship_path}") }
          }
          if @build_related
            links[:related] = { href: url_builder.build_url(path: "/v3/#{@relation_url}/#{@relationship_path}") }
          end

          links
        end
      end
    end
  end
end
