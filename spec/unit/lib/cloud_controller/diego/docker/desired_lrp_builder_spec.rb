require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe DesiredLrpBuilder do
        subject(:builder) { DesiredLrpBuilder.new(config, opts) }
        let(:opts) do
          {
            ports: ports,
            docker_image: 'user/repo:tag',
            execution_metadata: execution_metadata,
            start_command: 'dd if=/dev/random of=/dev/null'
          }
        end
        let(:config) do
          Config.new({
                       diego: {
                         lifecycle_bundles: {
                           docker: 'http://docker.example.com/path/to/lifecycle.tgz'
                         },
                         enable_declarative_asset_downloads: enable_declarative_asset_downloads
                       }
                     })
        end
        let(:ports) { [] }
        let(:execution_metadata) { '{}' }
        let(:enable_declarative_asset_downloads) { false }

        describe '#root_fs' do
          it 'uses the DockerURIConverter' do
            converter = instance_double(DockerURIConverter, convert: 'foobar')
            allow(DockerURIConverter).to receive(:new).and_return(converter)

            expect(builder.root_fs).to eq('foobar')
            expect(converter).to have_received(:convert).with('user/repo:tag')
          end
        end

        describe '#cached_dependencies' do
          before do
            allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('foo://bar.baz')
          end

          it 'returns an array of CachedDependency objects' do
            expect(builder.cached_dependencies).to eq([
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'foo://bar.baz',
                to: '/tmp/lifecycle',
                cache_key: 'docker-lifecycle'
              )
            ])
            expect(LifecycleBundleUriGenerator).to have_received(:uri).with('http://docker.example.com/path/to/lifecycle.tgz')
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns nil' do
              expect(builder.cached_dependencies).to be_nil
            end
          end
        end

        describe '#image_layers' do
          before do
            allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('foo://bar.baz')
          end

          it 'returns empty array' do
            expect(builder.image_layers).to be_empty
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'creates a image layer for each cached dependency' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name: 'docker-lifecycle',
                  url: 'foo://bar.baz',
                  destination_path: '/tmp/lifecycle',
                  layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                  media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
                )
              )
            end
          end
        end

        describe '#setup' do
          it 'returns nil' do
            expect(builder.setup).to be_nil
          end
        end

        describe '#global_environment_variables' do
          it 'returns an empty list' do
            expect(builder.global_environment_variables).to be_empty
          end
        end

        describe '#ports' do
          context 'when ports is an empty array' do
            let(:ports) { [] }
            let(:execution_metadata) do
              {
                ports: [
                  { 'port' => '1', 'protocol' => 'udp' },
                  { 'port' => '2', 'protocol' => 'udp' },
                  { 'port' => '3', 'protocol' => 'tcp' },
                  { 'port' => '4', 'protocol' => 'tcp' }
                ]
              }.to_json
            end

            it 'sets PORT to the first TCP port entry from execution_metadata' do
              expect(builder.ports).to eq([3, 4])
            end

            context 'when the ports array does not contain any TCP entries' do
              let(:execution_metadata) do
                { ports: [{ 'port' => '1', 'protocol' => 'udp' }] }.to_json
              end

              it 'raises an error' do
                expect do
                  builder.ports
                end.to raise_error(CloudController::Errors::ApiError, /No tcp ports found in image metadata/)
              end
            end

            context 'when the execution_metadata has an empty array of ports' do
              let(:execution_metadata) do
                { ports: [] }.to_json
              end

              it 'returns an array containing only the default' do
                expect(builder.ports).to eq([DEFAULT_APP_PORT])
              end
            end

            context 'when the execution_metadata does not contain ports' do
              let(:execution_metadata) do
                {}.to_json
              end

              it 'returns an array containing only the default' do
                expect(builder.ports).to eq([DEFAULT_APP_PORT])
              end
            end
          end
        end

        describe '#action_user' do
          it 'returns "root"' do
            expect(builder.action_user).to eq('root')
          end

          context 'when the execution metadata has a specified user' do
            let(:execution_metadata) { { user: 'foobar' }.to_json }

            it 'uses the user from the execution metadata' do
              expect(builder.action_user).to eq('foobar')
            end
          end
        end

        describe '#start_command' do
          it 'returns the passed in start command' do
            expect(builder.start_command).to eq('dd if=/dev/random of=/dev/null')
          end
        end

        describe '#port_environment_variables' do
          let(:ports) { [11, 22, 33] }

          it 'returns the array of environment variables' do
            expect(builder.port_environment_variables).to contain_exactly(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '11'))
          end
        end
      end
    end
  end
end
