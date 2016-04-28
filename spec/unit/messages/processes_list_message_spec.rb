require 'spec_helper'
require 'messages/processes_list_message'

module VCAP::CloudController
  describe ProcessesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'     => 1,
          'per_page' => 5,
          'app_guid' => 'some-app-guid',
          'types'     => 'web',
        }
      end

      it 'returns the correct ProcessesListMessage' do
        message = ProcessesListMessage.from_params(params)

        expect(message).to be_a(ProcessesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guid).to eq('some-app-guid')
        expect(message.types).to eq(['web'])
      end

      it 'converts requested keys to symbols' do
        message = ProcessesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:app_guid)).to be_truthy
        expect(message.requested?(:types)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          ProcessesListMessage.new({
              page:               1,
              per_page:           5,
              app_guid:           'some-app-guid'

          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = ProcessesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ProcessesListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
