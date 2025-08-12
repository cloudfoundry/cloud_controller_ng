require 'spec_helper'
require 'cloud_controller/diego/staging_action_builder'

module VCAP::CloudController
  module Diego
    RSpec.describe StagingActionBuilder do
      subject(:builder) { described_class.new(config, nil, nil, nil, nil, nil, nil) }

      let(:config) { Config.new({ staging: { legacy_md5_buildpack_paths_enabled: } }) }

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
