require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataModel do
    let(:buildpack_lifecycle_data_model) { BuildpackLifecycleDataModel.new }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:value_to_encrypt) { 'https://acme-buildpack.com' }
      let(:encrypted_attr) { :buildpack_without_serialization }
      let(:storage_column) { :encrypted_buildpack }
      let(:attr_salt) { :salt }
    end

    describe '#stack' do
      it 'persists the stack' do
        buildpack_lifecycle_data_model.stack = 'cflinuxfs2'
        buildpack_lifecycle_data_model.save
        expect(buildpack_lifecycle_data_model.reload.stack).to eq 'cflinuxfs2'
      end
    end

    describe '#buildpack' do
      it 'persists the buildpack' do
        buildpack_lifecycle_data_model.buildpack = 'ruby'
        buildpack_lifecycle_data_model.save
        expect(buildpack_lifecycle_data_model.reload.buildpack).to eq 'ruby'
      end
    end

    describe '#to_hash' do
      let(:expected_lifecycle_data) do
        { buildpack: buildpack, stack: 'cflinuxfs2' }
      end
      let(:buildpack) { 'ruby' }
      let(:stack) { 'cflinuxfs2' }

      before do
        buildpack_lifecycle_data_model.stack = stack
        buildpack_lifecycle_data_model.buildpack = buildpack
        buildpack_lifecycle_data_model.save
      end

      it 'returns the lifecycle data as a hash' do
        expect(buildpack_lifecycle_data_model.to_hash).to eq expected_lifecycle_data
      end

      context 'when the user has not specified a buildpack' do
        let(:buildpack) { nil }

        it 'returns the lifecycle data as a hash' do
          expect(buildpack_lifecycle_data_model.to_hash).to eq expected_lifecycle_data
        end
      end

      context 'when the buildpack is an url' do
        let(:buildpack) { 'https://github.com/puppychutes' }

        it 'returns the lifecycle data as a hash' do
          expect(buildpack_lifecycle_data_model.to_hash).to eq expected_lifecycle_data
        end

        it 'calls out to UrlSecretObfuscator' do
          allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)

          buildpack_lifecycle_data_model.to_hash

          expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
        end
      end
    end

    describe 'associations' do
      it 'can be associated with a droplet' do
        droplet = DropletModel.make
        buildpack_lifecycle_data_model.droplet = droplet
        buildpack_lifecycle_data_model.save
        expect(buildpack_lifecycle_data_model.reload.droplet).to eq(droplet)
      end

      it 'can be associated with apps' do
        app = AppModel.make
        buildpack_lifecycle_data_model.app = app
        buildpack_lifecycle_data_model.save
        expect(buildpack_lifecycle_data_model.reload.app).to eq(app)
      end

      it 'cannot be associated with both apps and droplets' do
        droplet = DropletModel.make
        app = AppModel.make
        buildpack_lifecycle_data_model.droplet = droplet
        buildpack_lifecycle_data_model.app = app
        expect(buildpack_lifecycle_data_model.valid?).to be(false)
        expect(buildpack_lifecycle_data_model.errors.full_messages.first).to include('Cannot be associated with both a droplet and an app')
      end
    end
  end
end
