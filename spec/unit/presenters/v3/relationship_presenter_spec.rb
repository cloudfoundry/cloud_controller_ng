require 'spec_helper'
require 'presenters/v3/relationship_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RelationshipPresenter do
    class Relationship
      def initialize(guid, name)
        @guid = guid
        @name = name
      end

      def guid
        @guid.to_s
      end

      def name
        @name
      end
    end

    def generate_relationships(count)
      relationships = []

      (1..count).each do |i|
        relationships << Relationship.new(i, 'name-' + i.to_s)
      end

      relationships
    end

    let(:data) { [] }
    subject(:relationship_presenter) { RelationshipPresenter.new('relationship', data) }

    describe '#to_hash' do
      let(:result) { relationship_presenter.to_hash }

      context 'when there are no relationships' do
        it 'does not populate the relationships' do
          expect(result[:data]).to be_empty
        end
      end

      context 'when there is a relationship data' do
        context 'a single relationship' do
          let(:data) { generate_relationships(1) }

          it 'returns a list of guids for the single relationship' do
            expect(result[:data]).to eq(
              [
                { name: 'name-1', guid: '1', link: '/v2/relationship/1' }
              ]
            )
          end
        end

        context 'for multiple relationships' do
          let(:data) { generate_relationships(5) }

          it 'returns a list of guids for each relationship' do
            expect(result[:data]).to eq(
              [
                { name: 'name-1', guid: '1', link: '/v2/relationship/1' },
                { name: 'name-2', guid: '2', link: '/v2/relationship/2' },
                { name: 'name-3', guid: '3', link: '/v2/relationship/3' },
                { name: 'name-4', guid: '4', link: '/v2/relationship/4' },
                { name: 'name-5', guid: '5', link: '/v2/relationship/5' }
              ]
            )
          end
        end
      end
    end
  end
end
