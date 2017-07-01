require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleBuildpackModel do
    subject(:buildpack) { BuildpackLifecycleBuildpackModel.new }

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
        expect(buildpack.valid?).to be_truthy
      end
      it 'expects unset buildpack buildpacks to be invalid' do
        expect(buildpack.valid?).to be_falsey
      end
      it 'expects doubly set buildpack buildpacks to be invalid' do
        buildpack.admin_buildpack_name = 'ruby'
        buildpack.buildpack_url = 'http://foo.org/ruby'
        expect(buildpack.valid?).to be_falsey
      end
    end

    describe '#buildpack_url' do
      it 'persists the buildpack' do
        buildpack.buildpack_url = 'http://buildpack.example.com'
        buildpack.save
        expect(buildpack.reload.buildpack_url).to eq 'http://buildpack.example.com'
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
          expect(buildpack.custom?).to eq true
        end
      end

      context 'when a buildpack_url is not set' do
        subject(:buildpack) { BuildpackLifecycleBuildpackModel.new(buildpack_url: nil) }

        it 'returns false' do
          expect(buildpack.custom?).to eq false
        end
      end
    end
  end
end
