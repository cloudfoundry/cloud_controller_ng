require 'spec_helper'
require 'messages/route_policies_list_message'

module VCAP::CloudController
  RSpec.describe RoutePoliciesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'guids' => 'guid1,guid2',
          'route_guids' => 'route1,route2',
          'space_guids' => 'space1,space2',
          'sources' => 'source1,source2',
          'source_guids' => 'resource1,resource2',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          'include' => 'source,route'
        }
      end

      it 'returns the correct RoutePoliciesListMessage' do
        message = RoutePoliciesListMessage.from_params(params)

        expect(message).to be_a(RoutePoliciesListMessage)
        expect(message.guids).to eq(%w[guid1 guid2])
        expect(message.route_guids).to eq(%w[route1 route2])
        expect(message.space_guids).to eq(%w[space1 space2])
        expect(message.sources).to eq(%w[source1 source2])
        expect(message.source_guids).to eq(%w[resource1 resource2])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.include).to eq(%w[source route])
      end

      it 'converts requested keys to symbols' do
        message = RoutePoliciesListMessage.from_params(params)

        expect(message).to be_requested(:guids)
        expect(message).to be_requested(:route_guids)
        expect(message).to be_requested(:space_guids)
        expect(message).to be_requested(:sources)
        expect(message).to be_requested(:source_guids)
        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:order_by)
        expect(message).to be_requested(:include)
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          guids: %w[guid1 guid2],
          route_guids: %w[route1 route2],
          space_guids: %w[space1 space2],
          sources: %w[source1 source2],
          source_guids: %w[resource1 resource2],
          page: 1,
          per_page: 5,
          order_by: 'created_at',
          include: %w[source route]
        }
      end

      it 'excludes the pagination keys' do
        expected_params = %i[guids route_guids space_guids sources source_guids include]
        expect(RoutePoliciesListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect do
          RoutePoliciesListMessage.from_params({
                                                 guids: [],
                                                 route_guids: [],
                                                 space_guids: [],
                                                 sources: [],
                                                 source_guids: [],
                                                 page: 1,
                                                 per_page: 5,
                                                 order_by: 'created_at',
                                                 include: %w[source route]
                                               })
        end.not_to raise_error
      end

      it 'accepts an empty set' do
        message = RoutePoliciesListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = RoutePoliciesListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'include validations' do
        it 'accepts valid include values' do
          message = RoutePoliciesListMessage.from_params({ 'include' => 'source' })
          expect(message).to be_valid

          message = RoutePoliciesListMessage.from_params({ 'include' => 'route' })
          expect(message).to be_valid

          message = RoutePoliciesListMessage.from_params({ 'include' => 'source,route' })
          expect(message).to be_valid
        end

        it 'rejects invalid include values' do
          message = RoutePoliciesListMessage.from_params({ 'include' => 'invalid' })
          expect(message).not_to be_valid

          message = RoutePoliciesListMessage.from_params({ 'include' => 'app' })
          expect(message).not_to be_valid

          message = RoutePoliciesListMessage.from_params({ 'include' => 'space' })
          expect(message).not_to be_valid

          message = RoutePoliciesListMessage.from_params({ 'include' => 'organization' })
          expect(message).not_to be_valid
        end
      end

      describe 'label_selector' do
        it 'accepts a label_selector param' do
          message = RoutePoliciesListMessage.from_params({ 'label_selector' => 'env=prod' })
          expect(message).to be_valid
          expect(message).to be_requested(:label_selector)
        end

        it 'rejects an invalid label_selector' do
          message = RoutePoliciesListMessage.from_params({ 'label_selector' => '%%invalid' })
          expect(message).not_to be_valid
        end
      end

      describe 'validations' do
        it 'validates space_guids is an array' do
          message = RoutePoliciesListMessage.from_params space_guids: 'not array'
          expect(message).not_to be_valid
          expect(message.errors[:space_guids].length).to eq 1
        end

        it 'allows space_guids to be nil' do
          message = RoutePoliciesListMessage.from_params({})
          expect(message).to be_valid
          expect(message.space_guids).to be_nil
        end

        it 'allows space_guids to be an array' do
          message = RoutePoliciesListMessage.from_params space_guids: %w[space1 space2]
          expect(message).to be_valid
          expect(message.space_guids).to eq(%w[space1 space2])
        end

        it 'validates source_guids is an array' do
          message = RoutePoliciesListMessage.from_params source_guids: 'not array'
          expect(message).not_to be_valid
          expect(message.errors[:source_guids].length).to eq 1
        end

        it 'allows source_guids to be nil' do
          message = RoutePoliciesListMessage.from_params({})
          expect(message).to be_valid
          expect(message.source_guids).to be_nil
        end

        it 'allows source_guids to be an array' do
          message = RoutePoliciesListMessage.from_params source_guids: %w[guid1 guid2]
          expect(message).to be_valid
          expect(message.source_guids).to eq(%w[guid1 guid2])
        end

        it 'validates sources is an array' do
          message = RoutePoliciesListMessage.from_params sources: 'not array'
          expect(message).not_to be_valid
          expect(message.errors[:sources].length).to eq 1
        end

        it 'allows sources to be nil' do
          message = RoutePoliciesListMessage.from_params({})
          expect(message).to be_valid
          expect(message.sources).to be_nil
        end

        it 'allows sources to be an array of valid source strings' do
          valid_uuid = '11111111-2222-3333-4444-555555555555'
          message = RoutePoliciesListMessage.from_params sources: [
            "cf:app:#{valid_uuid}",
            "cf:space:#{valid_uuid}",
            "cf:org:#{valid_uuid}",
            'cf:any'
          ]
          expect(message).to be_valid
        end

        it 'rejects sources containing invalid format' do
          message = RoutePoliciesListMessage.from_params sources: ['not-valid']
          expect(message).not_to be_valid
          expect(message.errors[:sources].length).to eq 1
          expect(message.errors[:sources][0]).to include('invalid source format')
        end

        it 'rejects sources where only some items are invalid' do
          valid_uuid = '11111111-2222-3333-4444-555555555555'
          message = RoutePoliciesListMessage.from_params sources: ["cf:app:#{valid_uuid}", 'bad-format']
          expect(message).not_to be_valid
          expect(message.errors[:sources][0]).to include('bad-format')
        end
      end
    end
  end
end
