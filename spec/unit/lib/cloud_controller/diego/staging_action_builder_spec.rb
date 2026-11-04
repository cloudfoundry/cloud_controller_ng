require 'spec_helper'
require 'cloud_controller/diego/staging_action_builder'

module VCAP::CloudController
  module Diego
    RSpec.describe StagingActionBuilder do
      subject(:builder) { described_class.new(config, nil, nil, nil, nil, nil, nil) }

      let(:config) { Config.new({ staging: { legacy_md5_buildpack_paths_enabled: } }) }

      %w[buildpack cnb].each do |prefix|
        context "with a custom stack and #{prefix} lifecycle assets" do
          subject(:builder) { described_class.new(config, nil, lifecycle_data, prefix, nil, nil, nil) }

          let(:enable_declarative_asset_downloads) { false }
          let(:config) do
            Config.new({
                         diego: {
                           lifecycle_bundles: { "#{prefix}/#{Stack.default.name}": 'platform-bundle' },
                           enable_declarative_asset_downloads: enable_declarative_asset_downloads
                         }
                       })
          end
          let(:lifecycle_data) do
            {
              stack: 'docker://registry.example.com/team/stack:v1',
              buildpacks: [],
              app_bits_checksum: { type: 'sha1' }
            }
          end

          before do
            allow(LifecycleBundleUriGenerator).to receive(:uri).with('platform-bundle').and_return('http://lifecycle.example.com/bundle.tgz')
          end

          it 'shares the platform lifecycle cache entry across custom image tags' do
            dependency = builder.cached_dependencies.first
            expect(dependency).to have_attributes(from: 'http://lifecycle.example.com/bundle.tgz', cache_key: "#{prefix}-#{Stack.default.name}-lifecycle")

            lifecycle_data[:stack] = 'docker://registry.example.com/team/stack:v2'
            expect(builder.cached_dependencies.first).to eq(dependency)
          end

          context 'with declarative asset downloads enabled' do
            let(:enable_declarative_asset_downloads) { true }

            it 'names the lifecycle layer after the platform stack' do
              expect(builder.image_layers.first).to have_attributes(
                name: "#{prefix}-#{Stack.default.name}-lifecycle",
                url: 'http://lifecycle.example.com/bundle.tgz',
                destination_path: '/tmp/lifecycle'
              )
            end
          end
        end
      end

      describe '#buildpack_path' do
        context 'when legacy_md5_buildpack_paths_enabled is false' do
          let(:legacy_md5_buildpack_paths_enabled) { false }

          it 'hashes buildpack key using XXH64' do
            expect(builder.send(:buildpack_path, 'key')).to eq('/tmp/buildpacks/447762562de14334')
          end

          it 'preserves leading zeros in the hash' do
            expect(builder.send(:buildpack_path, 'cl')).to eq('/tmp/buildpacks/00d7b37f249a2722')
          end
        end

        context 'when legacy_md5_buildpack_paths_enabled is true' do
          let(:legacy_md5_buildpack_paths_enabled) { true }

          it 'uses MD5 to hash the buildpack key' do
            expect(builder.send(:buildpack_path, 'key')).to eq('/tmp/buildpacks/3c6e0b8a9c15224a8228b9a98ca1531d')
          end
        end
      end
    end
  end
end
