require 'spec_helper'
require 'presenters/v3/relationship_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RelationshipPresenter do
    class Relationship
      def initialize(guid)
        @guid = guid
      end

      def guid
        @guid.to_s
      end
    end

    def generate_relationships(count)
      relationships = []

      (1..count).each do |i|
        relationships << Relationship.new(i)
      end

      relationships
    end

    let(:data) { [] }
    subject(:relationship_presenter) { RelationshipPresenter.new(data) }

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
                { guid: '1' }
              ]
            )
          end
        end

        context 'for multiple relationships' do
          let(:data) { generate_relationships(5) }

          it 'returns a list of guids for each relationship' do
            expect(result[:data]).to eq(
              [
                { guid: '1' },
                { guid: '2' },
                { guid: '3' },
                { guid: '4' },
                { guid: '5' }
              ]
            )
          end
        end
      end
    end
  end
end
