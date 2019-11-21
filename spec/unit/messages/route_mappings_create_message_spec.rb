require 'spec_helper'
require 'messages/route_mappings_create_message'

module VCAP::CloudController
  RSpec.describe RouteMappingsCreateMessage do
    let(:body) do
      {
        'relationships' => {
          'route'   => { 'guid' => 'some-route-guid' },
          'process' => { 'type' => 'web' }
        }
      }
    end

    it 'returns the correct AppRouteMappingsCreateMessage' do
      message = RouteMappingsCreateMessage.new(body)

      expect(message).to be_a(RouteMappingsCreateMessage)
      expect(message.route_guid).to eq('some-route-guid')
      expect(message.process_type).to eq('web')
    end

    it 'converts requested keys to symbols' do
      message = RouteMappingsCreateMessage.new(body)
      expect(message.requested?(:relationships)).to be_truthy
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            unexpected:    'woah',
            app_port:      '1234',
            relationships: {
              route:   { guid: 'some-route-guid' },
              process: { type: 'web' }
            }
          }
        end

        it 'is not valid' do
          message = RouteMappingsCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected', 'app_port'")
        end
      end

      describe 'weight' do
        let(:message) { RouteMappingsCreateMessage.new(body) }
        context 'when weight is NOT provided' do
          let(:body) do
            {
              'relationships' => {
                'app' => { 'guid' => 'some-app-guid' },
                'route'   => { 'guid' => 'some-route-guid' },
                'process' => { 'type' => 'web' }
              }
            }
          end
          it 'is valid' do
            expect(message).to be_valid
          end
        end

        context 'when weight is provided' do
          let(:body) do
            {
              'relationships' => {
                'app' => { 'guid' => 'some-app-guid' },
                'route'   => { 'guid' => 'some-route-guid' },
                'process' => { 'type' => 'web' }
              },
              'weight' => weight
            }
          end

          context 'when weight is less than 1' do
            let(:weight) { 0 }

            it 'is invalid' do
              expect(message).to be_invalid
              expect(message.errors[:weight]).to include('0 must be an integer between 1 and 128')
            end
          end

          context 'when weight is greater than 128' do
            let(:weight) { 129 }

            it 'is invalid' do
              expect(message).to be_invalid
              expect(message.errors[:weight]).to include('129 must be an integer between 1 and 128')
            end
          end

          context 'when weight is between 1 and 128' do
            let(:weight) { 128 }

            it 'is valid' do
              expect(message).to be_valid
            end
          end
        end
      end

      describe 'app' do
        it 'is not valid when app is missing' do
          message = RouteMappingsCreateMessage.new({ relationships: {} })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be an object')
        end

        it 'is not valid when app is not an object' do
          message = RouteMappingsCreateMessage.new({ relationships: { app: 'hello' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be an object')
        end

        it 'is not valid when app_guid has an invalid guid' do
          message = RouteMappingsCreateMessage.new({ relationships: { app: { guid: 876 } } })
          expect(message).not_to be_valid
          expect(message.errors_on(:app_guid)).to_not be_empty
        end
      end

      describe 'route' do
        it 'is not valid when route is missing' do
          message = RouteMappingsCreateMessage.new({})
          expect(message).not_to be_valid
          expect(message.errors_on(:route)).to include('must be an object')
        end

        it 'is not valid when route is not an object' do
          message = RouteMappingsCreateMessage.new({ relationships: { route: 'potato' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:route)).to include('must be an object')
        end

        it 'is not valid when route_guid has an invalid guid' do
          message = RouteMappingsCreateMessage.new(relationships: { route: { guid: 123 }, })
          expect(message).not_to be_valid
          expect(message.errors_on(:route_guid)).not_to be_empty
        end
      end

      describe 'process' do
        it 'is not valid when process is not an object' do
          message = RouteMappingsCreateMessage.new({ relationships: { process: 'not-a-hash' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:process)).to include('must be an object')
        end

        it 'is valid when process is missing' do
          message = RouteMappingsCreateMessage.new({})
          expect(message.errors_on(:process)).to be_empty
        end

        it 'is not valid when process type is not a string' do
          message = RouteMappingsCreateMessage.new({ relationships: { process: { type: 123 } } })
          expect(message).not_to be_valid
          expect(message.errors_on(:process_type)).to include('must be a string')
        end

        it 'is valid when process type is nil' do
          message = RouteMappingsCreateMessage.new({ relationships: { process: { type: nil } } })
          expect(message.errors_on(:process_type)).to be_empty
        end

        it 'defaults process_type to "web"' do
          message = RouteMappingsCreateMessage.new({ relationships: { process: { type: nil } } })
          expect(message.process_type).to eq('web')
        end
      end
    end
  end
end
