module VCAP::CloudController
  module Presenters
    module V3
      class OneToOneRelationshipPresenter
        def initialize(relation_url, relationship, relationship_path)
          @relation_url = relation_url
          @relationship = relationship
          @relationship_path = relationship_path
        end

        def to_hash
          {
            data: build_relation,
            links: {
              self: { href: url_builder.build_url(path: "/v3/#{@relation_url}/relationships/#{@relationship_path}") },
            }
          }
        end

        private

        def url_builder
          VCAP::CloudController::Presenters::ApiUrlBuilder.new
        end

        def build_relation
          return nil if @relationship.nil?
          { guid: @relationship.guid }
        end
      end
    end
  end
end
