module VCAP::CloudController
  module Presenters
    module V3
      class RelationshipPresenter
        def initialize(relationship)
          @relationship = relationship
        end

        def to_hash
          {
            data: build_relations
          }
        end

        private

        def build_relations
          data = []

          @relationship.each do |relation|
            data << { guid: relation.guid }
          end

          data
        end
      end
    end
  end
end
