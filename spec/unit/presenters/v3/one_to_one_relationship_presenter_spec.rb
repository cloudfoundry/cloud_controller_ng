require 'spec_helper'
require 'presenters/v3/one_to_one_relationship_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OneToOneRelationshipPresenter do
    class OneToOneRelationship
      def initialize(guid)
        @guid = guid
      end

      def guid
        @guid.to_s
      end
    end

    let(:relationship) { OneToOneRelationship.new(1) }
    subject(:relationship_presenter) { OneToOneRelationshipPresenter.new('relation/guid', relationship, 'relationship_path') }

    describe '#to_hash' do
      let(:result) { relationship_presenter.to_hash }

      context 'when there are no relationships' do
        let(:relationship) { nil }

        it 'does not populate the relationships' do
          expect(result[:data]).to eq(nil)
        end
      end

      context 'when there is a relationship data' do
        context 'a single relationship' do
          it 'returns the guid of the relationship' do
            expect(result[:data]).to eq(
              { guid: '1' }
            )
          end

          it 'returns a link to self' do
            expect(result[:links]).to eq(
              { self: { href: "#{link_prefix}/v3/relation/guid/relationships/relationship_path" } }
            )
          end
        end
      end
    end
  end
end
