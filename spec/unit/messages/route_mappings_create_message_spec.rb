require 'spec_helper'
require 'messages/route_mappings_create_message'

module VCAP::CloudController
  RSpec.describe RouteMappingsCreateMessage do
    let(:body) do
      {
        'app_port' => 1234,
        'relationships' => {
          'route'    => { 'guid' => 'some-route-guid' },
          'process'  => { 'type' => 'web' }
        }
      }
    end

    it 'returns the correct AppRouteMappingsCreateMessage' do
      message = RouteMappingsCreateMessage.create_from_http_request(body)

      expect(message).to be_a(RouteMappingsCreateMessage)
      expect(message.route_guid).to eq('some-route-guid')
      expect(message.app_port).to eq(1234)
      expect(message.process_type).to eq('web')
    end

    it 'converts requested keys to symbols' do
      message = RouteMappingsCreateMessage.create_from_http_request(body)
      expect(message.requested?(:relationships)).to be_truthy
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            unexpected: 'woah',
            relationships: {
              route: { guid: 'some-route-guid' },
              process: { type: 'web' }
            }
          }
        end

        it 'is not valid' do
          message = RouteMappingsCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'app_port' do
        let(:body) do
          {
          relationships: {
              route: { guid: 'some-route-guid' },
              process: { type: 'web' },
              app: { guid: '123' }
            }
          }
        end

        context 'when app_port is present' do
          it 'is valid' do
            body[:app_port] = 8888
            message = RouteMappingsCreateMessage.new(body)
            expect(message).to be_valid
          end

          it 'is not valid when app_port is a string' do
            body[:app_port] = 'trout'
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors_on(:app_port)).to include('is not a number')
          end

          it 'is not valid when app_port is a fraction' do
            body[:app_port] = 7.8
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors_on(:app_port)).to include('must be an integer')
          end

          it 'is not valid when app_port is less than 0' do
            body[:app_port] = -1
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors_on(:app_port)).to include('must be greater than 0')
          end
        end

        context 'when app_port is not present' do
          it 'is not valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end

      describe 'app' do
        it 'is not valid when app is missing' do
          message = RouteMappingsCreateMessage.new({ relationships: {} })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be a hash')
        end

        it 'is not valid when app is not a hash' do
          message = RouteMappingsCreateMessage.new({ relationships: { app: 'hello' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be a hash')
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
          expect(message.errors_on(:route)).to include('must be a hash')
        end

        it 'is not valid when route is not a hash' do
          message = RouteMappingsCreateMessage.new({ relationships: { route: 'potato' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:route)).to include('must be a hash')
        end

        it 'is not valid when route_guid has an invalid guid' do
          message = RouteMappingsCreateMessage.new(relationships: { route: { guid: 123 }, })
          expect(message).not_to be_valid
          expect(message.errors_on(:route_guid)).not_to be_empty
        end
      end

      describe 'process' do
        it 'is not valid when process is not a hash' do
          message = RouteMappingsCreateMessage.new({ relationships: { process: 'not-a-hash' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:process)).to include('must be a hash')
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
