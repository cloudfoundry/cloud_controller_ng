require 'spec_helper'
require 'messages/service_credential_binding_create_message'

module VCAP::CloudController
  RSpec.describe ServiceCredentialBindingCreateMessage do
    subject { ServiceCredentialBindingCreateMessage }

    let(:params) {
      {
        type: 'app',
        name: 'some-name',
        parameters: {
            some_param: 'very important',
            another_param: 'epa'
        },
        relationships: {
          service_instance: { data: { guid: 'some-instance-guid' } }
        },
        metadata: {
          labels: { foo: 'bar' },
          annotations: { foz: 'baz' }
        }
      }
    }

    describe '.from_params' do
      let(:message) { subject.new(params) }

      it 'builds a valid ServiceCredentialBindingCreateMessage' do
        expect(message).to be_valid
        expect(message.type).to eq('app')
        expect(message.name).to eq('some-name')
        expect(message.service_instance_guid).to eq('some-instance-guid')
        expect(message.parameters).to eq({ some_param: 'very important', another_param: 'epa' })
        expect(message.metadata).to eq({ labels: { foo: 'bar' }, annotations: { foz: 'baz' } })
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
        it 'accepts empty' do
          params[:name] = ''
          expect(subject.new(params)).to be_valid
        end

        it 'accepts nil' do
          params.delete(:name)
          expect(subject.new(params)).to be_valid
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
          params[:relationships][:foo] = {}
          params[:relationships].delete(:service_instance)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Service instance can't be blank")
        end

        it 'returns an invalid message when there is relationship object is empty' do
          params[:relationships].delete(:service_instance)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships 'relationships' must include one or more valid relationships")
        end
      end
    end
  end
end
