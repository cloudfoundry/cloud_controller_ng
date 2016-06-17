require 'spec_helper'
require 'messages/service_binding_create_message'

module VCAP::CloudController
  RSpec.describe ServiceBindingCreateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'type' => 'pipe',
          'relationships' => {
            'app' => {
              'guid' => 'fluid'
            },
            'service_instance' => {
              'guid' => 'druid'
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
      context 'service_instance' do
        context 'when service instance guid is not a string' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                app: {
                  guid: 'fluid'
                },
                service_instance: {
                  guid: true
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:service_instance_guid)).to include('must be a string')
          end
        end

        context 'when service_instance does not exist' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                app: {
                  guid: 'fluid'
                }
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("Service instance can't be blank")
          end
        end

        context 'when service instance guid is malformed' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                app: {
                  guid: 'fluid'
                },
                service_instance: {
                  what: 'how do you guid'
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/Service instance must be structured like this: \"service_instance: {\"guid\": \"valid-guid"}\"/)
          end
        end
      end

      context 'app_guid' do
        context 'when app guid is not a string' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                app: {
                  guid: true
                },
                service_instance: {
                  guid: 'druid'
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:app_guid)).to include('must be a string')
          end
        end

        context 'when the app guid does not exist' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                service_instance: {
                  guid: 'druid'
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("App can't be blank")
          end
        end

        context 'when the app guid is malformed' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                app: {
                  nap: 'now'
                },
                service_instance: {
                  guid: 'druid'
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include(/App must be structured like this: \"app: {\"guid\": \"valid-guid"}\"/)
          end
        end
      end

      context 'when unexpected keys are requested' do
        let(:symbolized_body) do
          {
            surprise_key: 'boo',
            type: 'app',
            relationships: {
              app: {
                guid: 'fluid'
              },
              service_instance: {
                guid: 'druid'
              },
            },
          }
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
            {
              type: true,
              relationships: {
                app: {
                  guid: 'fluid'
                },
                service_instance: {
                  guid: 'druid'
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:type)).to include('must be a string')
          end
        end

        context 'when type does not exist' do
          let(:symbolized_body) do
            {
              relationships: {
                app: {
                  guid: 'fluid'
                },
                service_instance: {
                  guid: 'druid'
                },
              },
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:type)).to include("can't be blank")
          end
        end

        context 'when the type is not an app' do
          let(:symbolized_body) do
            {
              type: 'not an app',
              relationships: {
                app: {
                  guid: 'fluid'
                },
                service_instance: {
                  guid: 'druid'
                },
              },
            }
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
            {
              type: 'app',
              relationships: {
                app: {
                  guid: true
                },
                service_instance: {
                  guid: 'druid'
                },

              },
              data: 'tricked you not a hash'
            }
          end

          it 'is not valid' do
            message = ServiceBindingCreateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:data)).to include('must be a hash')
          end
        end

        context 'when data includes unexpected keys' do
          let(:symbolized_body) do
            {
              type: 'app',
              relationships: {
                app: {
                  guid: 'fluid'
                },
                service_instance: {
                  guid: 'druid'
                },

              },
              data: {
                sparameters: 'not a valid field'
              }
            }
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
