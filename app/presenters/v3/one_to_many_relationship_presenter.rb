module VCAP::CloudController
  module Presenters
    module V3
      class OneToManyRelationshipPresenter
        def initialize(relation_url, relationships)
          @relation_url = relation_url
          @relationships = relationships
          @url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
        end

        def to_hash
          {
            data: build_relations,
            links: build_links
          }
        end

        private

        def build_relations
          data = []

          @relationships.each do |relationship|
            data << { guid: relationship.guid }
          end

          data
        end

        def build_links
          {
            self: {
              href: @url_builder.build_url(path: "/v3/#{@relation_url}/relationships/organizations")
            },
            related: {
              href: @url_builder.build_url(path: "/v3/#{@relation_url}/organizations")
            }
          }
        end
      end
    end
  end
end
