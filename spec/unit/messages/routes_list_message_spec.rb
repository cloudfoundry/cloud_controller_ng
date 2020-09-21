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

      it 'accepts a ports param' do
        message = RoutesListMessage.from_params({ 'ports' => '5900,6000,7000' })
        expect(message).to be_valid
        expect(message.ports).to eq(['5900', '6000', '7000'])
      end

      it 'does not accept any other params' do
        message = RoutesListMessage.from_params({ 'app_guid' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'app_guid'")
      end

      it 'does accepts domain,space, and space.organization' do
        message = RoutesListMessage.from_params({ 'include' => 'domain' })
        expect(message).to be_valid
        message = RoutesListMessage.from_params({ 'include' => 'space' })
        expect(message).to be_valid
        message = RoutesListMessage.from_params({ 'include' => 'space.organization' })
        expect(message).to be_valid
        message = RoutesListMessage.from_params({ 'include' => 'eli\'s buildpack' })
        expect(message).not_to be_valid
      end

      it 'invalidates duplicates in the includes field' do
        message = RoutesListMessage.from_params 'include' => 'domain,domain'
        expect(message).to be_invalid
        expect(message.errors[:base].length).to eq 1
        expect(message.errors[:base][0]).to match(/Duplicate included resource: 'domain'/)
      end

      context 'when app guids param is provided' do
        it 'accepts it' do
          message = RoutesListMessage.from_params({ 'app_guids' => 'guid1,guid2' })
          expect(message).to be_valid
          expect(message.app_guids).to eq(['guid1', 'guid2'])
        end
      end
    end
  end
end
