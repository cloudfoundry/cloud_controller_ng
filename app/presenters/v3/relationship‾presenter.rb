module VCAP::CloudController
  module Presenters
    module V3
      class RelationshipPresenter
        def initialize(relation_url, relationships)
          @relation_url = relation_url
          @relationships = relationships
        end

        def to_hash
          {
            data: build_relations
          }
        end

        private

        def build_relations
          data = []

          @relationships.each do |relationship|
            data << { name: relationship.name, guid: relationship.guid, link: "/v2/#{@relation_url}/#{relationship.guid}" }
          end

          data
        end
      end
    end
  end
end
