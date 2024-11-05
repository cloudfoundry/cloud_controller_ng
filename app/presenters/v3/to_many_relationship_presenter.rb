require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ToManyRelationshipPresenter < BasePresenter
        def initialize(relation_url, relationships, relationship_path, build_related: true, decorators: [])
          @relation_url = relation_url
          @relationships = relationships
          @relationship_path = relationship_path
          @build_related = build_related
          @decorators = decorators
        end

        def to_hash
          relations = build_relations
          h = {
            data: relations,
            links: build_links
          }

          @decorators.reduce(h) { |memo, d| d.decorate(memo, @relationships) }
        end

        private

        def build_relations
          @relationships.map do |relationship|
            { guid: relationship.guid }
          end
        end

        def build_links
          links = {
            self: { href: url_builder.build_url(path: "/v3/#{@relation_url}/relationships/#{@relationship_path}") }
          }
          links[:related] = { href: url_builder.build_url(path: "/v3/#{@relation_url}/#{@relationship_path}") } if @build_related

          links
        end
      end
    end
  end
end
