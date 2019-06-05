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

      it 'accepts a hosts param' do
        message = RoutesListMessage.from_params({ 'hosts' => 'host1,host2' })
        expect(message).to be_valid
        expect(message.hosts).to eq(['host1', 'host2'])
      end

      it 'accepts a hosts param' do
        message = RoutesListMessage.from_params({ 'space_guids' => 'guid1,guid2' })
        expect(message).to be_valid
        expect(message.space_guids).to eq(['guid1', 'guid2'])
      end

      it 'accepts a paths param' do
        message = RoutesListMessage.from_params({ 'paths' => '/path1,/path2' })
        expect(message).to be_valid
        expect(message.paths).to eq(['/path1', '/path2'])
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
        message = RoutesListMessage.from_params({ 'foobar' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
