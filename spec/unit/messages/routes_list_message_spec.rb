require 'spec_helper'
require 'messages/routes_list_message'

module VCAP::CloudController
  RSpec.describe RoutesListMessage do
    describe '.from_params' do
      let(:params) do
        { 'label_selector' => 'animal in (cat,dog)' }
      end

      it 'returns the correct RoutesListMessage' do
        message = RoutesListMessage.from_params(params)

        expect(message).to be_a(RoutesListMessage)
        expect(message.label_selector).to eq('animal in (cat,dog)')
      end
    end

    describe '#for_app_guid' do
      it 'sets app_guid on message' do
        message = RoutesListMessage.from_params({}).for_app_guid('some-app-guid')
        expect(message.app_guid).to eq('some-app-guid')
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = RoutesListMessage.from_params({})
        expect(message).to be_valid
      end

      context 'when hosts param is provided' do
        context 'with a value' do
          it 'accepts it' do
            message = RoutesListMessage.from_params({ 'hosts' => 'host1,host2' })
            expect(message).to be_valid
            expect(message.hosts).to eq(['host1', 'host2'])
          end
        end

        context 'without a value' do
          it 'accepts it and treats it as an empty string value' do
            message = RoutesListMessage.from_params({ 'hosts' => '' })
            expect(message).to be_valid
            expect(message.hosts).to eq([''])
          end
        end
      end

      it 'accepts a space_guids param' do
        message = RoutesListMessage.from_params({ 'space_guids' => 'guid1,guid2' })
        expect(message).to be_valid
        expect(message.space_guids).to eq(['guid1', 'guid2'])
      end

      context 'when paths param is provided' do
        context 'with a value' do
          it 'accepts it' do
            message = RoutesListMessage.from_params({ 'paths' => '/path1,/path2' })
            expect(message).to be_valid
            expect(message.paths).to eq(['/path1', '/path2'])
          end
        end

        context 'without a value' do
          it 'accepts it and treats it as an empty string value' do
            message = RoutesListMessage.from_params({ 'paths' => '' })
            expect(message).to be_valid
            expect(message.paths).to eq([''])
          end
        end
      end

      it 'accepts an organization_guids param' do
        message = RoutesListMessage.from_params({ 'organization_guids' => 'guid1,guid2' })
        expect(message).to be_valid
        expect(message.organization_guids).to eq(['guid1', 'guid2'])
      end

      it 'accepts an domain_guids param' do
        message = RoutesListMessage.from_params({ 'domain_guids' => 'guid1,guid2' })
        expect(message).to be_valid
        expect(message.domain_guids).to eq(['guid1', 'guid2'])
      end

      it 'does not accept any other params' do
        message = RoutesListMessage.from_params({ 'app_guid' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'app_guid'")
      end
    end
  end
end
