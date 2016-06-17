require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe ClientProvider do
      let(:options) { { blobstore_type: blobstore_type } }

      context 'when no type is requested' do
        let(:blobstore_type) { nil }

        before do
          options.merge!(fog_connection: {})
        end

        it 'provides a fog client' do
          allow(FogClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(FogClient).to have_received(:new)
        end
      end

      context 'when fog is requested' do
        let(:blobstore_type) { 'fog' }

        before do
          options.merge!(fog_connection: {})
        end

        it 'provides a fog client' do
          allow(FogClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(FogClient).to have_received(:new)
        end

        context 'when an aws encryption option is requested' do
          before do
            options.merge!(fog_aws_storage_options: { encryption: 'my organic algo' })
          end

          it 'passes the specified encryption option to the fog client' do
            allow(FogClient).to receive(:new).and_call_original
            ClientProvider.provide(options: options, directory_key: 'key')
            expect(FogClient).to have_received(:new).with(connection_config: anything,
                                                          directory_key: anything,
                                                          cdn: anything,
                                                          root_dir: anything,
                                                          min_size: anything,
                                                          max_size: anything,
                                                          encryption: 'my organic algo')
          end
        end

        context 'when a cdn is requested in the options' do
          before do
            options.merge!(cdn: { uri: 'http://cdn.com' })
          end

          it 'sets up a cdn for the fog client' do
            allow(FogClient).to receive(:new).and_call_original
            ClientProvider.provide(options: options, directory_key: 'key')
            expect(FogClient).to have_received(:new).with(connection_config: anything,
                                                          directory_key: anything,
                                                          cdn: an_instance_of(Cdn),
                                                          root_dir: anything,
                                                          min_size: anything,
                                                          max_size: anything,
                                                          encryption: anything)
          end
        end

        context 'when fog_connection is not provided' do
          before do
            options.delete(:fog_connection)
          end

          it 'raises an error' do
            expect { ClientProvider.provide(options: options, directory_key: 'key') }.to raise_error(KeyError)
          end
        end
      end

      context 'when webdav is requested' do
        let(:blobstore_type) { 'webdav' }

        before do
          options.merge!(webdav_config: { private_endpoint: 'http://private.example.com', public_endpoint: 'http://public.example.com' })
        end

        it 'provides a webdav client' do
          allow(DavClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(DavClient).to have_received(:new)
        end
      end
    end
  end
end
