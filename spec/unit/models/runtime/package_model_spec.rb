require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PackageModel do
    describe 'validations' do
      it { is_expected.to validates_includes PackageModel::PACKAGE_STATES, :state, allow_missing: true }

      it 'cannot have docker data if it is a bits package' do
        package = PackageModel.new(type: 'bits', docker_image: 'some-image')
        expect(package.valid?).to be(false)

        expect(package.errors.full_messages).to include('type cannot have docker data if type is bits')
      end

      it 'can have a password with length 16k characters' do
        package = PackageModel.new(type: 'docker', docker_password: 'a' * 5000)
        package2 = PackageModel.new(type: 'docker', docker_password: 'a' * 5001)
        expect(package).to be_valid
        expect(package2).not_to be_valid
        expect(package2.errors.full_messages).to include('docker_password can be up to 5,000 characters')
      end
    end

    describe 'bits_image_reference' do
      let(:package_sha256_checksum) { 'sha256-checksum' }
      let(:type) { PackageModel::BITS_TYPE }
      let(:package) { PackageModel.make(sha256_checksum: package_sha256_checksum, type: type) }

      context 'when using a package registry' do
        before do
          TestConfig.override(packages: { image_registry: { base_path: 'hub.example.com/user' } })
        end

        it 'returns the image reference for the package' do
          expect(package.bits_image_reference).to eq("hub.example.com/user/#{package.guid}")
        end

        context 'when digest: true is given' do
          it 'returns the image reference for the package, including the digest' do
            expect(package.bits_image_reference(digest: true)).to eq("hub.example.com/user/#{package.guid}@sha256:#{package_sha256_checksum}")
          end
        end

        context 'when the package is type DOCKER' do
          let(:type) { PackageModel::DOCKER_TYPE }

          it 'raises an error' do
            expect do
              package.bits_image_reference
            end.to raise_error('Package type must be bits')
          end
        end
      end

      context 'when not using a package registry' do
        it 'raises an error' do
          expect do
            package.bits_image_reference
          end.to raise_error('Package Registry is not configured')
        end
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

    describe '#succeed_upload!' do
      let!(:package) { PackageModel.make state: PackageModel::PENDING_STATE }

      it 'updates the checksums and moves the package state to READY' do
        package.succeed_upload!(sha1: 'sha-1-checksum', sha256: 'sha-2-checksum')
        package.reload
        expect(package.package_hash).to eq('sha-1-checksum')
        expect(package.sha256_checksum).to eq('sha-2-checksum')
        expect(package.state).to eq(PackageModel::READY_STATE)
      end

      context 'when the package has been deleted before finishing upload' do
        it 'does not error' do
          PackageModel.find(guid: package.guid).destroy
          expect do
            package.succeed_upload!(sha1: 'sha-1-checksum', sha256: 'sha-2-checksum')
          end.not_to raise_error
        end
      end
    end

    describe 'metadata' do
      let(:package) { PackageModel.make }
      let(:annotation) { PackageAnnotationModel.make(package:) }
      let(:label) { PackageLabelModel.make(package:) }

      it 'can access its metadata' do
        expect(annotation.package.guid).to eq(package.guid)
        expect(label.package.guid).to eq(package.guid)
        expect(package.labels).to contain_exactly(label)
        expect(package.annotations).to contain_exactly(annotation)
      end
    end
  end
end
