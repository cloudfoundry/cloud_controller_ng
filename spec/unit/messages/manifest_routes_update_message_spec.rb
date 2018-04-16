require 'spec_helper'
require 'messages/manifest_routes_update_message'

module VCAP::CloudController
  RSpec.describe ManifestRoutesUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) do
        {'routes' =>
          [
            {'route' => 'existing.example.com'},
            {'route' => 'new.example.com'},
          ]
        }
      end

      it 'returns the correct ManifestRoutesMessage' do
        message = ManifestRoutesUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(ManifestRoutesUpdateMessage)
        expect(message.routes).to_not be_nil
        expect(message.route_hashes).to match_array([
          {
            potential_host: 'existing',
            potential_domains: ['existing.example.com', 'example.com'],
            port: nil,
            path: ''
          },
          {
            potential_host: 'new',
            potential_domains: ['new.example.com', 'example.com'],
            port: nil,
            path: ''
          }
        ])
      end
    end

    describe 'yaml validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            routes: [
              {route: 'existing.example.com'},
            ],
            surprise_key: 'surprise'
          }
        end

        it 'is not valid' do
          message = ManifestRoutesUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'surprise_key'")
        end
      end

      context 'when routes is not an array' do
        let(:body) do
          {routes: 'im-so-not-an-array'}
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.create_from_http_request(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route hashes')
        end
      end

      context 'when routes is an array of unexpected format' do
        let(:body) do
          {routes: [{'route' => 'path.com'}, 'foo.land']}
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.create_from_http_request(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route hashes')
        end
      end
    end

    describe 'route validations' do
      context 'when all routes are valid' do
        let(:body) do
          {'routes' =>
            [
              {'route' => 'existing.example.com'},
              {'route' => 'new.example.com'},
            ]
          }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.create_from_http_request(body)

          expect(msg.valid?).to eq(true)
        end
      end

      context 'when a route is invalid' do
        let(:body) do
          {'routes' =>
            [
              {'route' => 'potato://bad.example.com'},
              {'route' => 'new.example.com'},
            ]
          }
        end

        it 'returns false' do
          msg = ManifestRoutesUpdateMessage.create_from_http_request(body)

          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include("The route 'potato://bad.example.com' is not a properly formed URL")
        end
      end
    end
  end
end
