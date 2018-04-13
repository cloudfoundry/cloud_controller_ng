require 'spec_helper'
require 'messages/manifest_routes_update_message'

module VCAP::CloudController
  RSpec.describe ManifestRoutesUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) do
        { 'routes' =>
          [
            { 'route' => 'existing.example.com' },
            { 'route' => 'new.example.com' },
            { 'route' => 'tcp-example.com:1234' },
            { 'route' => 'path.example.com/path' },
            { 'route' => '*.example.com' },
          ]
        }
      end

      it 'returns the correct ManifestRoutesMessage' do
        message = ManifestRoutesUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(ManifestRoutesUpdateMessage)
        expect(message.routes).to_not be_nil
        expect(message.routes).to match_array([
          { route: 'existing.example.com' },
          { route: 'new.example.com' },
          { route: 'tcp-example.com:1234' },
          { route: 'path.example.com/path' },
          { route: '*.example.com' }
        ])
      end
    end

    describe 'validations' do
      context 'when routes is not an array' do
        let(:body) do
          { routes: 'im-so-not-an-array' }
        end

        it 'is not valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors).to match_array('routes must be a list of route hashes')
        end
      end

      context 'when routes is an array of unexpected format' do
        let(:body) do
          { routes: [{'route' => 'path.com'}, 'foo.land'] }
        end

        it 'is not valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors).to match_array('routes must be a list of route hashes')
        end
      end

      context 'when no routes are specified' do
        let(:body) do
          { routes: [] }
        end

        it 'is valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when there is a port' do
        let(:body) do
          { routes: [{ route: 'tcp-example.com:1234' }] }
        end

        it 'is valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when there is a tcp protocol' do
        let(:body) do
          { routes: [{ route: 'tcp://www.example.com' }] }
        end

        it 'is valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when there is a protocol other than tcp or http' do
        let(:body) do
          { routes: [{ route: 'ftp://www.example.com' }] }
        end

        it 'is invalid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).not_to be_valid
        end
      end

      context 'when there is a route with a path' do
        let(:body) do
          { routes: [{ route: 'path.example.com/path' }] }
        end

        it 'is valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when there is a wildcard route' do
        let(:body) do
          { routes: [{ route: '*.example.com' }] }
        end

        it 'is valid' do
          message = ManifestRoutesUpdateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when invalid route formats are provided' do
        let(:body) do
          { routes:
            [
              { route: 'blah' },
              { route: 'anotherblah' },
              { route: 'http://example.com' },
            ]
          }
        end

        it 'is not valid' do
          message = ManifestRoutesUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors).to match_array(["The route 'anotherblah' is not a properly formed URL", "The route 'blah' is not a properly formed URL"])
        end
      end

      context 'when there is a nil route' do
        let(:body) do
          { routes: [{ route: nil }] }
        end

        it 'is invalid' do
          message = ManifestRoutesUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors).to match_array("The route '' is not a properly formed URL")
        end
      end

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
    end
  end
end
