require 'spec_helper'
require 'messages/manifest_routes_update_message'

module VCAP::CloudController
  RSpec.describe ManifestRoutesUpdateMessage do
    describe 'yaml validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            routes: [
              { route: 'existing.example.com' }
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
          expect(msg.valid?).to be(true)
        end
      end

      context 'when no_route is not a boolean' do
        let(:body) do
          { 'no_route' => 'tru' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
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
            { 'route' => 'new.example.com' }
          ]
        end

        it 'is valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(true)
        end
      end

      context 'when no_route is false and routes are specified' do
        let(:body) do
          {
            'no_route' => false,
            'routes' => [
              { 'route' => 'existing.example.com' },
              { 'route' => 'new.example.com' }
            ]
          }
        end

        it 'is valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(true)
        end
      end

      context 'when routes is not an array' do
        let(:body) do
          { routes: 'im-so-not-an-array' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route objects')
        end
      end

      context 'when routes is an array of unexpected format' do
        let(:body) do
          { routes: [{ 'route' => 'path.com' }, 'foo.land'] }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route objects')
        end
      end

      context 'when routes is an array of invalid route objects' do
        let(:body) do
          { routes: [{ 'route' => 'path.com' }, { 'root' => 'path.com' }] }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include('Routes must be a list of route objects')
        end
      end

      context 'when random_route is not a boolean' do
        let(:body) do
          { 'random_route' => 'vicuna' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include('Random-route must be a boolean')
        end
      end

      context 'when default_route is not a boolean' do
        let(:body) do
          { 'default_route' => 'vicuna' }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include('Default-route must be a boolean')
        end
      end

      context 'when random_route and default_route are used together' do
        let(:body) do
          { 'random_route' => true, 'default_route' => true }
        end

        it 'is not valid' do
          msg = ManifestRoutesUpdateMessage.new(body)
          expect(msg.valid?).to be(false)
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
              { 'route' => 'new.example.com', 'protocol' => 'http2' }
            ] }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(true)
        end
      end

      context 'when a route is invalid' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'potato://bad.example.com' },
              { 'route' => 'new.example.com' }
            ] }
        end

        it 'returns false' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include("The route 'potato://bad.example.com' is not a properly formed URL")
        end
      end

      context 'when a route has an invalid protocol' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'existing.example.com', 'protocol' => 'bologna' },
              { 'route' => 'http2.example.com', 'protocol' => 'http2' },
              { 'route' => 'http1.example.com', 'protocol' => 'http1' },
              { 'route' => 'tcp.example.com', 'protocol' => 'tcp' }
            ] }
        end

        it 'returns false' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include("Route protocol must be 'http1', 'http2' or 'tcp'.")
        end
      end

      context 'when a route contains empty route options' do
        let(:body) do
          { 'routes' =>
              [
                { 'route' => 'existing.example.com',
                  'options' => {} }
              ] }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(true)
        end
      end

      context 'when a route contains nil route option' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'existing.example.com',
                'options' => nil }
            ] }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include("Route 'existing.example.com': options must be an object")
        end
      end

      context 'when a route contains invalid route options' do
        let(:body) do
          { 'routes' =>
              [
                { 'route' => 'existing.example.com',
                  'options' => { 'invalid' => 'invalid' } }
              ] }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(false)
          expect(msg.errors.errors.length).to eq(1)
          expect(msg.errors.full_messages).to include("Route 'existing.example.com' contains invalid route option 'invalid'. Valid keys: 'loadbalancing'")
        end
      end

      context 'when a route contains a valid value for loadbalancing' do
        let(:body) do
          { 'routes' =>
              [
                { 'route' => 'existing.example.com',
                  'options' => {
                    'loadbalancing' => 'round-robin'
                  } }
              ] }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(true)
        end
      end

      context 'when a route contains null as a value for loadbalancing' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'existing.example.com',
                'options' => {
                  'loadbalancing' => nil
                } }
            ] }
        end

        it 'returns true' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(false)
          expect(msg.errors.full_messages).to include("Invalid value for 'loadbalancing' for Route 'existing.example.com'; Valid values are: 'round-robin, least-connection'")
        end
      end

      context 'when a route contains an invalid value for loadbalancing' do
        let(:body) do
          { 'routes' =>
            [
              { 'route' => 'existing.example.com',
                'options' => {
                  'loadbalancing' => 'sushi'
                } }
            ] }
        end

        it 'returns false' do
          msg = ManifestRoutesUpdateMessage.new(body)

          expect(msg.valid?).to be(false)
          expect(msg.errors.errors.length).to eq(1)
          expect(msg.errors.full_messages).to include("Cannot use loadbalancing value 'sushi' for Route 'existing.example.com'; Valid values are: 'round-robin, least-connection'")
        end
      end
    end
  end
end
