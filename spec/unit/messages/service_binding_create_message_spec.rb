require 'spec_helper'
require 'messages/service_bindings/service_binding_create_message'

module VCAP::CloudController
  RSpec.describe ServiceBindingCreateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'type' => 'pipe',
          'relationships' => {
            'app' => {
              'data' => {
                'guid' => 'fluid'
              }
            },
            'service_instance' => {
              'data' => {
                'guid' => 'druid'
              }
            },
          },
        }
      }

      it 'returns the correct ServiceBindingCreateMessage' do
        message = ServiceBindingCreateMessage.create_from_http_request(body)

        expect(message).to be_a(ServiceBindingCreateMessage)
        expect(message.type).to eq('pipe')
        expect(message.app_guid).to eq('fluid')
        expect(message.service_instance_guid).to eq('druid')
      end
    end

    describe 'validations' do
      let(:valid_body) {
        {
          type: 'app',
          relationships: {
            app: {
              data: {
                guid: 'fluid'
              }
            },
            service_instance: {
              data: {
                guid: 'druid'
              }
            },
          },
        }
      }

      context 'when all values are correct' do
        let(:symbolized_body) { valid_body }

        it 'is valid' do
          message = ServiceBindingCreateMessage.new(symbolized_body)
          expect(message).to be_valid
        end
      end

      context 'service_instance' do
        context 'when service instance guid is not a string' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships][:service_instance] = {
                data: {
                  guid: true
                }
              }
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include('Service instance guid must be a string')
          end
        end

        context 'when service_instance relationship is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships].delete(:service_instance)
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("Service instance can't be blank")
          end
        end

        context 'when the service instance data key is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships][:service_instance] = { guid: 'How important could that data key be?' }
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/Service instance must be structured like this: \"service_instance: {\"data\": {\"guid\": \"valid-guid"}}\"/)
          end
        end

        context 'when the service instance guid is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships][:service_instance] = {
                data: {
                  what: 'how do you guid'
                }
              }
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/Service instance must be structured like this: \"service_instance: {\"data\": {\"guid\": \"valid-guid"}}\"/)
          end
        end

        context 'when the relationship hash is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash.delete(:relationships)
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/'relationships' is not a hash/)
          end
        end

        context 'when relationships is not a hash' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships] = 'not a hash'
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/'relationships' is not a hash/)
          end
        end
      end

      context 'app_guid' do
        context 'when app guid is not a string' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships][:app] = {
                data: {
                  guid: true
                }
              }
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include('App guid must be a string')
          end
        end

        context 'when the app key is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships].delete(:app)
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("App can't be blank")
          end
        end

        context 'when the app data key is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships][:app] = { guid: 'How important could that data key be?' }
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/App must be structured like this: "app: {"data": {"guid": "valid-guid"}}"/)
          end
        end

        context 'when the app guid is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash[:relationships][:app] = {
                data: {
                  nap: 'now'
                }
              }
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/App must be structured like this: "app: {"data": {"guid": "valid-guid"}}"/)
          end
        end
      end

      context 'when unexpected keys are requested' do
        let(:symbolized_body) do
          valid_body.merge(surprise_key: 'boo')
        end

        it 'is not valid' do
          message = ServiceBindingCreateMessage.new(symbolized_body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'surprise_key'")
        end
      end

      context 'type' do
        context 'when type is not a string' do
          let(:symbolized_body) do
            valid_body.merge(type: true)
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:type)).to include('must be a string')
          end
        end

        context 'when type key is missing' do
          let(:symbolized_body) do
            valid_body.tap do |hash|
              hash.delete(:type)
            end
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:type)).to include("can't be blank")
          end
        end

        context 'when the type is not an app' do
          let(:symbolized_body) do
            valid_body.merge(type: 'not an app')
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:type)).to include('type must be app')
          end
        end
      end

      describe 'parameters' do
        context 'when data is not provided' do
          let(:symbolized_body) { {} }

          it 'is nil' do
            message = ServiceBindingCreateMessage.new(symbolized_body)
            expect(message.parameters).to be_nil
          end
        end

        context 'when data is provided but parameters are not' do
          let(:symbolized_body) do
            {
              data: {}
            }
          end

          it 'is nil' do
            message = ServiceBindingCreateMessage.new(symbolized_body)
            expect(message.parameters).to be_nil
          end
        end

        context 'when provided' do
          let(:symbolized_body) do
            {
              data: {
                parameters: { cool: 'parameters' }
              }
            }
          end

          it 'is accessible' do
            message = ServiceBindingCreateMessage.new(symbolized_body)
            expect(message.parameters).to eq(cool: 'parameters')
          end
        end
      end

      context 'data' do
        context 'when data is not a hash' do
          let(:symbolized_body) do
            valid_body.merge(data: 'tricked you not a hash')
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:data)).to include('must be a hash')
          end
        end

        context 'when data includes unexpected keys' do
          let(:symbolized_body) do
            valid_body.merge(data: { sparameters: 'not a valid field' })
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:data)).to include("Unknown field(s): 'sparameters'")
          end
        end
      end
    end
  end
end
