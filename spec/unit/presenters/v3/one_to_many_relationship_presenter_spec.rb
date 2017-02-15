require 'spec_helper'
require 'presenters/v3/one_to_many_relationship_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OneToManyRelationshipPresenter do
    class OneToManyRelationship
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
        relationships << OneToManyRelationship.new(i)
      end

      relationships
    end

    let(:data) { [] }
    let(:relation_url) { 'isolation_segments/aaabbbccc' }
    subject { OneToManyRelationshipPresenter.new(relation_url, data) }
    let(:url_builder) { VCAP::CloudController::Presenters::ApiUrlBuilder.new }

    describe '#to_hash' do
      let(:result) { subject.to_hash }

      context 'when there are no relationships' do
        it 'does not populate the relationships' do
          expect(result[:data]).to be_empty
        end

        it 'provides a links section' do
          expect(result[:links]).to eq({
            self: {
              href: url_builder.build_url(path: "/v3/#{relation_url}/relationships/organizations")
            },
            related: {
              href: url_builder.build_url(path: "/v3/#{relation_url}/organizations")
            }
          }
          )
        end
      end

      context 'when there is relationship data' do
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
