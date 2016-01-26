require 'spec_helper'
require 'messages/route_mappings_create_message'

module VCAP::CloudController
  describe RouteMappingsCreateMessage do
    let(:body) do
      {
        'relationships' => {
          'route'   => { 'guid' => 'some-route-guid' },
          'process' => { 'type' => 'web' }
        }
      }
    end

    it 'returns the correct AppRouteMappingsCreateMessage' do
      message = RouteMappingsCreateMessage.create_from_http_request(body)

      expect(message).to be_a(RouteMappingsCreateMessage)
      expect(message.route_guid).to eq('some-route-guid')
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

      describe 'route' do
        context 'when route is not a hash' do
          let(:body) do
            {
              relationships: {
                route: 'sdf',
                process: { type: 'web' }
              }
            }
          end
          it 'is not valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
          end
        end

        context 'when route_guid has an invalid guid' do
          let(:body) do
            {
              relationships: {
                route: { guid: 123 },
                process: { type: 'web' }
              }
            }
          end
          it 'is not valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
          end
        end
      end

      describe 'process' do
        context 'when process is not hash' do
          let(:body) do
            {
              relationships: {
                route: { guid: 'some-guid' },
                process: 'not-a-hash'
              }
            }
          end

          it 'is not valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
          end
        end

        context 'when process is missing' do
          let(:body) do
            {
              relationships: {
                route: { guid: 'some-guid' }
              }
            }
          end
          it 'is valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        context 'when process type is not a string' do
          let(:body) do
            {
              relationships: {
                route: { guid: 'some-guid' },
                process: { type: 123 }
              }
            }
          end

          it 'is not valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).not_to be_valid
          end
        end

        context 'when process type is nil' do
          let(:body) do
            {
              relationships: {
                route: { guid: 'some-guid' },
                process: nil
              }
            }
          end

          it 'is valid' do
            message = RouteMappingsCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end
    end
  end
end
