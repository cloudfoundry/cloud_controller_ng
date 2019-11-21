require 'spec_helper'
require 'messages/manifest_routes_update_message'

module VCAP::CloudController
  RSpec.describe ManifestRoutesUpdateMessage do
    describe 'yaml validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            routes: [
              { route: 'existing.example.com' },
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

      context 'when no_route is requested' do
        let(:body) do
          { 'no_route' => true }
        end

        it 'is valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(true)
        end
      end

      context 'when no_route is not a boolean' do
        let(:body) do
          { 'no_route' => 'tru' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('No-route must be a boolean')
        end
      end

      context 'when no_route is true and routes are specified' do
        let(:body) do
          {
            'no_route' => true,
            'routes' => routes
          }
        end

        let(:routes) do
          [
            { 'route' => 'existing.example.com' },
            { 'route' => 'new.example.com' },
          ]
        end

        it 'is valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(true)
        end
      end

      context 'when no_route is false and routes are specified' do
        let(:body) do
          {
            'no_route' => false,
            'routes' => [
              { 'route' => 'existing.example.com' },
              { 'route' => 'new.example.com' },
            ]
          }
        end

        it 'is  valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(true)
        end
      end

      context 'when routes is not an array' do
        let(:body) do
          { routes: 'im-so-not-an-array' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route objects')
        end
      end

      context 'when routes is an array of unexpected format' do
        let(:body) do
          { routes: [{ 'route' => 'path.com' }, 'foo.land'] }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route objects')
        end
      end

      context 'when routes is an array of invalid route objects' do
        let(:body) do
          { routes: [{ 'route' => 'path.com' }, { 'root' => 'path.com' }] }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route objects')
        end
      end

      context 'when random_route is not a boolean' do
        let(:body) do
          { 'random_route' => 'vicuna' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Random-route must be a boolean')
        end
      end

      context 'when default_route is not a boolean' do
        let(:body) do
          { 'default_route' => 'vicuna' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Default-route must be a boolean')
        end
      end

      context 'when random_route and default_route are used together' do
        let(:body) do
          { 'random_route' => true, 'default_route' => true }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include('Random-route and default-route may not be used together')
        end
      end
    end

    describe 'route validations' do
      context 'when all routes are valid' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'existing.example.com' },
              { 'route' => 'new.example.com' },
            ]
          }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to eq(true)
        end
      end

      context 'when a route is invalid' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'potato://bad.example.com' },
              { 'route' => 'new.example.com' },
            ]
          }
        end

        it 'returns false' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to eq(false)
          expect(msg.errors.full_messages).to include("The route 'potato://bad.example.com' is not a properly formed URL")
        end
      end
    end
  end
end
