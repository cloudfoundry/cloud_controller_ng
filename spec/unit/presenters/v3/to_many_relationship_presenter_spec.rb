require 'spec_helper'
require 'presenters/v3/to_many_relationship_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ToManyRelationshipPresenter do
    class ToManyRelationship
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
        relationships << ToManyRelationship.new(i)
      end

      relationships
    end

    let(:data) { [] }
    let(:build_related) { true }
    let(:relation_url) { 'cash/guid' }
    let(:relationship_path) { 'money' }
    subject(:relationship_presenter) { ToManyRelationshipPresenter.new(relation_url, data, relationship_path, build_related: build_related) }
    let(:url_builder) { VCAP::CloudController::Presenters::ApiUrlBuilder.new }

    describe '#to_hash' do
      let(:result) { relationship_presenter.to_hash }

      context 'when there are no relationships' do
        it 'does not populate the relationships' do
          expect(result[:data]).to be_empty
        end

        it 'provides a links section' do
          expect(result[:links]).to eq({
            self: {
              href: url_builder.build_url(path: "/v3/#{relation_url}/relationships/#{relationship_path}")
            },
            related: {
              href: url_builder.build_url(path: "/v3/#{relation_url}/#{relationship_path}")
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

      context 'when build_related is false' do
        let(:build_related) { false }
        it 'does not include a related field in links' do
          expect(result[:links]).to eq({
            self: {
              href: url_builder.build_url(path: "/v3/#{relation_url}/relationships/#{relationship_path}")
            }
          })
        end
      end
    end
  end
end
