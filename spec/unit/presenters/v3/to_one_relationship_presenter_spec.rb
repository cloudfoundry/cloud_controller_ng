require 'spec_helper'
require 'presenters/v3/to_one_relationship_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ToOneRelationshipPresenter do
    let(:book_class) {
      Class.new do
        def initialize(guid)
          @guid = guid
        end

        def guid
          @guid.to_s
        end
      end
    }

    let(:resource_path) { 'readers/1234' }
    let(:related_resource_name) { 'books' }
    let(:related_instance_guid) { '1' }
    let(:related_instance) { book_class.new(related_instance_guid) }
    let(:relationship_name) { 'favorite_book' }
    subject(:relationship_presenter) do
      ToOneRelationshipPresenter.new(
        resource_path: resource_path,
        related_instance: related_instance,
        relationship_name: relationship_name,
        related_resource_name: related_resource_name
      )
    end

    describe '#to_hash' do
      let(:result) { relationship_presenter.to_hash }

      context 'when there are no relationships' do
        let(:related_instance) { nil }

        it 'does not populate the relationships' do
          expect(result).to eq({
            data: nil,
            links: { self: { href: "#{link_prefix}/v3/#{resource_path}/relationships/#{relationship_name}" } }
          })
        end
      end

      context 'when there is a relationship data' do
        context 'a single relationship' do
          it 'returns the guid of the relationship' do
            expect(result[:data]).to eq(
              { guid: related_instance_guid }
            )
          end

          it 'returns a link to self' do
            expect(result[:links]).to match(hash_including(
                                              { self: { href: "#{link_prefix}/v3/#{resource_path}/relationships/#{relationship_name}" } }
            ))
          end
        end

        context 'related' do
          it 'includes a link to the related resource' do
            expect(result[:links]).to match(hash_including(
                                              { related: { href: "#{link_prefix}/v3/#{related_resource_name}/#{related_instance_guid}" } }
            ))
          end
        end
      end
    end
  end
end
