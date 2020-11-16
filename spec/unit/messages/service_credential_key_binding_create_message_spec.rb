require 'spec_helper'
require 'messages/service_credential_key_binding_create_message'

module VCAP::CloudController
  RSpec.describe ServiceCredentialKeyBindingCreateMessage do
    subject { ServiceCredentialKeyBindingCreateMessage }

    let(:params) {
      {
        type: 'key',
        name: 'some-name',
        parameters: {
            some_param: 'very important',
            another_param: 'epa'
        },
        relationships: {
          service_instance: { data: { guid: 'some-instance-guid' } },
        }
      }
    }

    describe '.from_params' do
      let(:message) { subject.new(params) }

      it 'builds a valid ServiceCredentialBindingCreateMessage' do
        expect(message).to be_valid
        expect(message.type).to eq('key')
        expect(message.name).to eq('some-name')
        expect(message.service_instance_guid).to eq('some-instance-guid')
        expect(message.parameters).to eq({ some_param: 'very important', another_param: 'epa' })
      end

      it 'converts requested keys to symbols' do
        params.each do |key, _|
          expect(message.requested?(key.to_sym)).to be_truthy
        end
      end

      it 'returns an invalid message when unexpected keys are included' do
        params[:size] = 10
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'size'")
      end

      context 'type' do
        it 'accepts app and key' do
          %w{app key}.each do |type|
            params[:type] = type
            expect(subject.new(params)).to be_valid
          end
        end

        it 'is invalid with any other value' do
          params[:type] = 'test'
          expect(subject.new(params)).not_to be_valid
        end
      end

      context 'name' do
        it 'does not accept empty' do
          params[:name] = ''
          expect(subject.new(params)).not_to be_valid
        end

        it 'does not accept nil' do
          params.delete(:name)
          expect(subject.new(params)).not_to be_valid
        end
      end

      context 'parameters' do
        it 'is invalid when not a hash' do
          params[:parameters] = 'aloha'
          expect(subject.new(params)).not_to be_valid
        end
      end

      describe 'relationships' do
        it 'returns an invalid message when there is no service instance relationship' do
          params[:relationships].delete(:service_instance)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships 'relationships' must include one or more valid relationships")
        end

        it 'returns an invalid message when there is invalid relationships' do
          params[:relationships][:app] = {}

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Unknown field(s): 'app'")
        end
      end
    end
  end
end
