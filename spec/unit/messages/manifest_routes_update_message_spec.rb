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

      context 'hash options validation' do
        context 'when hash_based_routing feature flag is disabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: false)
          end

          context 'when a route contains loadbalancing=hash' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash'
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include(
                "Cannot use loadbalancing value 'hash' for Route 'existing.example.com'; Valid values are: 'round-robin, least-connection'"
              )
            end
          end

          context 'when a route contains hash_header' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'hash_header' => 'X-User-ID'
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include(
                "Route 'existing.example.com' contains invalid route option 'hash_header'. Valid keys: 'loadbalancing'"
              )
            end
          end

          context 'when a route contains hash_balance' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'hash_balance' => '1.5'
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com' contains invalid route option 'hash_balance'. Valid keys: 'loadbalancing'")
            end
          end

          context 'when a route contains hash_balance with round-robin loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'round-robin',
                      'hash_balance' => '1.2'
                    } }
                ] }
            end

            it 'returns false with only one error (invalid option), and skips hash-based routing specific error messages' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com' contains invalid route option 'hash_balance'. Valid keys: 'loadbalancing'")
              expect(msg.errors.full_messages).not_to include("Route 'existing.example.com': Hash balance can only be set when loadbalancing is hash")
              expect(msg.errors.full_messages.length).to eq(1)
            end
          end

          context 'when a route contains both hash_header and hash_balance' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => '1.5'
                    } }
                ] }
            end

            it 'returns false with appropriate error' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              # Should get error for invalid route options (both hash_header and hash_balance are invalid)
              expect(msg.errors.full_messages.any? { |m| m.include?('contains invalid route option') }).to be(true)
            end
          end
        end

        context 'when hash_based_routing feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
          end

          context 'when a route contains hash_header with hash loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID'
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_balance with hash loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => '1.5'
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_header without loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'hash_header' => 'X-User-ID'
                    } }
                ] }
            end

            it 'returns true (loadbalancing is omitted)' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_header longer than 128 characters' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X' * 129
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash header must be at most 128 characters")
            end
          end

          context 'when a route contains hash_header exactly 128 characters' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X' * 128
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_balance without loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => '2.0'
                    } }
                ] }
            end

            it 'returns true (loadbalancing is omitted)' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_header with non-hash loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'round-robin',
                      'hash_header' => 'X-User-ID'
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash header can only be set when loadbalancing is hash")
            end
          end

          context 'when a route contains hash_balance with non-hash loadbalancing' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'least-connection',
                      'hash_balance' => '1.5'
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash balance can only be set when loadbalancing is hash")
            end
          end

          context 'when a route contains non-numeric hash_balance' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'hash_balance' => 'not-a-number'
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash balance must be a numeric value")
            end
          end

          context 'when a route contains hash_balance of 0' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => 0
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_balance between 0 and 1.1' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => 0.5
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash balance must be either 0 or between 1.1 and 10.0")
            end
          end

          context 'when a route contains hash_balance of 1.1' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => 1.1
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_balance greater than 10.0' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => 10.1
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash balance must be either 0 or between 1.1 and 10.0")
            end
          end

          context 'when a route contains hash_balance exactly 10.0' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => 10.0
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains numeric string hash_balance' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => '2.5'
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains float hash_balance' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => 1.5
                    } }
                ] }
            end

            it 'returns true' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains hash_balance longer than 16 characters' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => '2.' + ('1' * 15)
                    } }
                ] }
            end

            it 'returns false' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash balance must be at most 16 characters")
            end
          end

          context 'when a route contains hash_balance exactly 16 characters' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID',
                      'hash_balance' => '2.' + ('1' * 14)
                    } }
                ] }
            end

            it 'returns true if the value is numeric and within range' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(true)
            end
          end

          context 'when a route contains multiple issues with hash options' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'existing.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X' * 129,
                      'hash_balance' => '2.' + ('1' * 15)
                    } }
                ] }
            end

            it 'returns false and prints all errors' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash header must be at most 128 characters")
              expect(msg.errors.full_messages).to include("Route 'existing.example.com': Hash balance must be at most 16 characters")
            end
          end

          context 'when multiple routes have mixed valid and invalid hash options' do
            let(:body) do
              { 'routes' =>
                [
                  { 'route' => 'valid1.example.com',
                    'options' => {
                      'loadbalancing' => 'hash',
                      'hash_header' => 'X-User-ID'
                    } },
                  { 'route' => 'invalid.example.com',
                    'options' => {
                      'loadbalancing' => 'round-robin',
                      'hash_header' => 'X-User-ID'
                    } },
                  { 'route' => 'valid2.example.com',
                    'options' => {
                      'hash_header' => 'X-Session-ID'
                    } }
                ] }
            end

            it 'returns false and reports the invalid route' do
              msg = ManifestRoutesUpdateMessage.new(body)

              expect(msg.valid?).to be(false)
              expect(msg.errors.full_messages).to include("Route 'invalid.example.com': Hash header can only be set when loadbalancing is hash")
            end
          end
        end
      end
    end
  end
end
