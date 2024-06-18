require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleBuildpackModel do
    subject(:buildpack) { BuildpackLifecycleBuildpackModel.new }
    let(:buildpack_lifecycle_data) { BuildpackLifecycleDataModel.make(buildpacks: ['ruby']) }

    before do
      Buildpack.make(name: 'ruby')
      buildpack.buildpack_lifecycle_data = buildpack_lifecycle_data
    end

    it_behaves_like 'a model with an encrypted attribute' do
      let(:model_factory) { -> { BuildpackLifecycleBuildpackModel.make(:custom_buildpack) } }
      let(:value_to_encrypt) { 'https://acme-buildpack.com' }
      let(:encrypted_attr) { :buildpack_url }
      let(:storage_column) { :encrypted_buildpack_url }
      let(:attr_salt) { :encrypted_buildpack_url_salt }
    end

    describe '#valid' do
      it 'expects buildpack buildpacks to be valid' do
        buildpack.admin_buildpack_name = 'ruby'
        expect(buildpack).to be_valid
      end

      it 'expects an unknown admin buildpack to be invalid' do
        buildpack.admin_buildpack_name = 'rust'
        expect(buildpack).not_to be_valid
        expect(buildpack.errors.full_messages.first).to include('Specified unknown buildpack name: "rust"')
      end

      it 'expects unset buildpack buildpacks to be invalid' do
        expect(buildpack).not_to be_valid
        expect(buildpack.errors.full_messages.first).to include('Must specify either a buildpack_url or an admin_buildpack_name')
      end

      it 'expects doubly set buildpack buildpacks to be invalid' do
        buildpack.admin_buildpack_name = 'ruby'
        buildpack.buildpack_url = 'http://foo.org/ruby'
        expect(buildpack).not_to be_valid
        expect(buildpack.errors.full_messages.first).to include('Must specify either a buildpack_url or an admin_buildpack_name')
      end

      it 'expects a non-URI custom buildpack name to be invalid' do
        buildpack.buildpack_url = 'not a valid URL'
        expect(buildpack).not_to be_valid
        expect(buildpack.errors.full_messages.first).to include('Specified invalid buildpack URL: "not a valid URL"')
      end

      context 'when a cnb buildpack is used' do
        let(:cnb_lifecycle_data) { CNBLifecycleDataModel.make(buildpacks: ['docker://nginx:latest']) }

        before do
          buildpack.buildpack_lifecycle_data = nil
          buildpack.cnb_lifecycle_data = cnb_lifecycle_data
        end

        it 'expects an URI without scheme to be invalid' do
          buildpack.admin_buildpack_name = nil
          buildpack.buildpack_url = 'nginx:latest'
          expect(buildpack).not_to be_valid
          expect(buildpack.errors.full_messages.first).to include('Specified invalid buildpack URL: "nginx:latest"')
        end

        it 'expects an URI with docker scheme to be valid' do
          buildpack.admin_buildpack_name = nil
          buildpack.buildpack_url = 'docker://nginx:latest'
          expect(buildpack).to be_valid
        end
      end
    end

    describe '#buildpack_url' do
      it 'persists the buildpack' do
        buildpack.buildpack_url = 'http://buildpack.example.com'
        buildpack.save
        expect(buildpack.reload.buildpack_url).to eq 'http://buildpack.example.com'
      end
    end

    describe '#version' do
      it 'persists the version' do
        buildpack.buildpack_url = 'http://buildpack.example.com'
        buildpack.version = '1.2.3'
        buildpack.save
        expect(buildpack.reload.version).to eq('1.2.3')
      end
    end

    describe '#buildpack_name' do
      it 'persists the buildpack_name' do
        buildpack.admin_buildpack_name = 'ruby'
        buildpack.buildpack_name = 'fez_buildpack'
        buildpack.save
        expect(buildpack.reload.buildpack_name).to eq('fez_buildpack')
      end
    end

    describe '#admin_buildpack_name' do
      it 'persists the buildpack' do
        buildpack.admin_buildpack_name = 'ruby'
        buildpack.save
        expect(buildpack.reload.admin_buildpack_name).to eq 'ruby'
      end
    end

    describe '#custom?' do
      context 'when a buildpack_url is set' do
        subject(:buildpack) { BuildpackLifecycleBuildpackModel.new(buildpack_url: 'http://example.com') }

        it 'returns true' do
          expect(buildpack.custom?).to be true
        end
      end

      context 'when a buildpack_url is not set' do
        subject(:buildpack) { BuildpackLifecycleBuildpackModel.new(buildpack_url: nil) }

        it 'returns false' do
          expect(buildpack.custom?).to be false
        end
      end
    end
  end
end
