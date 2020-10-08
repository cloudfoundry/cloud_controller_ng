require 'spec_helper'
require 'registry_buddy/client'

module RegistryBuddy
  RSpec.describe Client do
    let(:registry_buddy_host) { '127.0.0.1' }
    let(:registry_buddy_port) { 8080 }
    subject(:client) { RegistryBuddy::Client.new(registry_buddy_host, registry_buddy_port) }

    describe '#post_package' do
      let(:status) { 200 }
      let(:response) { '{}' }

      before do
        stub_request(:post, "http://#{registry_buddy_host}:#{registry_buddy_port}/packages").
          with(body: {
            'package_zip_path' => '/path/to/package.zip',
            'package_guid' => 'a-package-guid',
            'registry_base_path' => 'docker.io/cfcapidocker'
          }).to_return(status: status, body: response)
      end

      context 'when the request succeeds' do
        let(:status) { 200 }
        let(:response) { '{"hash":{"algorithm":"sha256","hex":"sha-2-5-6-hex"}}' }

        it 'returns the OCI Image sha' do
          expect(client.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker')).to eq(
            'hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' }
          )
        end
      end

      context 'when RegistryBuddy returns a 422' do
        let(:status) { 422 }
        let(:response) { 'unprocessable entity' }

        it 'raises a RegistryBuddy::Error' do
          expect { client.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker') }.
            to raise_error(RegistryBuddy::Error, /Unprocessable Entity error/)
        end
      end

      context 'when RegistryBuddy returns a 400' do
        let(:status) { 400 }
        let(:response) { 'bad request' }

        it 'raises a RegistryBuddy::Error' do
          expect { client.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker') }.
            to raise_error(RegistryBuddy::Error, /Bad Request error/)
        end
      end

      context 'when RegistryBuddy returns a 500' do
        let(:status) { 500 }
        let(:response) { 'bad response' }

        it 'raises a RegistryBuddy::Error' do
          expect { client.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker') }.
            to raise_error(RegistryBuddy::Error, /Server error/)
        end
      end
    end

    describe '#delete_image' do
      let(:status) { 202 }
      let(:response) { '{}' }

      let(:image_reference) { 'reference-to-my-image' }

      before do
        stub_request(:delete, "http://#{registry_buddy_host}:#{registry_buddy_port}/images").
          to_return(status: status, body: response)
      end

      it 'sends the request to the server' do
        client.delete_image(image_reference)

        expect(WebMock).to have_requested(:delete,
          "http://#{registry_buddy_host}:#{registry_buddy_port}/images"
        ).with(body: JSON.dump('image_reference' => image_reference))
      end

      context 'when the request succeeds' do
        let(:status) { 202 }
        let(:response) { '{}' }

        it 'returns nil' do
          expect(client.delete_image(image_reference)).to be_nil
        end
      end

      context 'when RegistryBuddy returns a 422' do
        let(:status) { 422 }
        let(:response) { 'unprocessable entity' }

        it 'raises a RegistryBuddy::Error' do
          expect { client.delete_image(image_reference) }.
            to raise_error(RegistryBuddy::Error, /Unprocessable Entity error/)
        end
      end

      context 'when RegistryBuddy returns a 400' do
        let(:status) { 400 }
        let(:response) { 'bad request' }

        it 'raises a RegistryBuddy::Error' do
          expect { client.delete_image(image_reference) }.
            to raise_error(RegistryBuddy::Error, /Bad Request error/)
        end
      end

      context 'when RegistryBuddy returns a 500' do
        let(:status) { 500 }
        let(:response) { 'bad response' }

        it 'raises a RegistryBuddy::Error' do
          expect { client.delete_image(image_reference) }.
            to raise_error(RegistryBuddy::Error, /Server error/)
        end
      end
    end
  end
end
