# encoding: utf-8

require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PackageModel do
    describe 'validations' do
      it { is_expected.to validates_includes PackageModel::PACKAGE_STATES, :state, allow_missing: true }

      it 'cannot have docker data if it is a bits package' do
        package = PackageModel.new(type: 'bits', docker_image: 'some-image')
        expect(package.valid?).to eq(false)

        expect(package.errors.full_messages).to include('type cannot have docker data if type is bits')
      end

      it 'can have a password with length 16k characters' do
        package = PackageModel.new(type: 'docker', docker_password: 'a' * 1000)
        package2 = PackageModel.new(type: 'docker', docker_password: 'a' * 1001)
        expect(package).to be_valid
        expect(package2).to_not be_valid
        expect(package2.errors.full_messages).to include('docker_password can be up to 1,000 characters')
      end
    end

    describe 'checksum_info' do
      let(:package) { PackageModel.new(state: PackageModel::READY_STATE) }
      context 'when the package has a sha1 hash and not a sha256 hash' do
        before do
          package.update(package_hash: 'sha1-hash', sha256_checksum: nil)
        end

        it 'displays the sha1' do
          expect(package.checksum_info).to eq({ type: 'sha1', value: 'sha1-hash' })
        end
      end

      context 'when the package has no checksums' do
        before do
          package.update(package_hash: nil, sha256_checksum: nil)
        end

        it 'displays the sha256 with null value' do
          expect(package.checksum_info).to eq({ type: 'sha256', value: nil })
        end
      end
    end

    describe 'docker credentials' do
      it_behaves_like 'a model with an encrypted attribute' do
        let(:value_to_encrypt) { 'password' }
        let(:encrypted_attr) { :docker_password }
        let(:storage_column) { :encrypted_docker_password }
        let(:attr_salt) { :docker_password_salt }
      end
    end
  end
end
