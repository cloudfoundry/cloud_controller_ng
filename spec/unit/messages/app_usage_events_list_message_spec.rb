require 'spec_helper'
require 'messages/app_usage_events_list_message'

module VCAP::CloudController
  RSpec.describe AppUsageEventsListMessage do
    subject { AppUsageEventsListMessage.from_params(params) }
    let(:params) { {} }

    it 'accepts an empty set' do
      expect(subject).to be_valid
    end

    context 'when there are valid params' do
      let(:params) do
        {
          'guids' => 'guid5,guid6',
        }
      end

      it 'accepts the params as valid' do
        expect(subject).to be_valid
      end
    end

    context 'when invalid params are given' do
      let(:params) { { foobar: 'pants' } }

      it 'does not accept any other params' do
        expect(subject).not_to be_valid
        expect(subject.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    context 'validations' do
      context 'when the guids filter is provided' do
        let(:params) { { 'guids' => 'some-guid' } }

        context 'and the values are invalid' do
          let(:params) { { guids: false } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:guids]).to include('must be an array')
          end
        end

        it 'sets the message types to the provided values' do
          expect(subject).to be_valid
          expect(subject.guids).to eq(['some-guid'])
        end
      end
    end
  end
end
