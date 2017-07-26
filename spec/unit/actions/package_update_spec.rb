require 'spec_helper'
require 'actions/package_update'

module VCAP::CloudController
  RSpec.describe PackageUpdate do
    subject(:package_update) { PackageUpdate.new }

    describe '#update' do
      let(:body) do
        {
          'state'     => 'READY',
          'checksums' => [
            {
              'type'  => 'sha1',
              'value' => 'potato'
            },
            {
              'type'  => 'sha256',
              'value' => 'potatoest'
            }
          ],
          'error' => 'nothing bad'
        }
      end
      let(:package) { PackageModel.make(state: PackageModel::PENDING_STATE) }
      let(:message) { InternalPackageUpdateMessage.create_from_http_request(body) }

      it 'updates the package' do
        package_update.update(package, message)

        package.reload
        expect(package.state).to eq(PackageModel::READY_STATE)
        expect(package.package_hash).to eq('potato')
        expect(package.sha256_checksum).to eq('potatoest')
        expect(package.error).to eq('nothing bad')
      end

      context 'when the package is already in READY_STATE' do
        let(:package) { PackageModel.make(state: PackageModel::READY_STATE) }

        it 'raises InvalidPackage' do
          expect {
            package_update.update(package, message)
          }.to raise_error(PackageUpdate::InvalidPackage, 'Invalid state. State is already final and cannot be modified.')
        end
      end

      context 'when the package is already in FAILED_STATE' do
        let(:package) { PackageModel.make(state: PackageModel::FAILED_STATE) }

        it 'raises InvalidPackage' do
          expect {
            package_update.update(package, message)
          }.to raise_error(PackageUpdate::InvalidPackage, 'Invalid state. State is already final and cannot be modified.')
        end
      end

      context 'when the package is transitioning to READY_STATE' do
        let(:body) { { 'state' => 'READY' } }

        context 'and the current state is COPYING' do
          let(:package) {
            PackageModel.make(
              state: PackageModel::COPYING_STATE,
              package_hash: 'existing-sha1',
              sha256_checksum: 'existing-sha256'
            )
          }

          it 'does not require checksums in the message' do
            package_update.update(package, message)

            package.reload
            expect(package.state).to eq(PackageModel::READY_STATE)
            expect(package.package_hash).to eq('existing-sha1')
            expect(package.sha256_checksum).to eq('existing-sha256')
          end
        end

        context 'and the current state is not COPYING' do
          [PackageModel::PENDING_STATE, PackageModel::CREATED_STATE, PackageModel::EXPIRED_STATE].each do |package_state|
            it 'requires checksums in the message' do
              package = PackageModel.make(state: package_state)
              expect {
                package_update.update(package, message)
              }.to raise_error(PackageUpdate::InvalidPackage, 'Checksums required when setting state to READY')
            end
          end
        end
      end

      context 'when the package is transitioning to FAILED_STATE' do
        let(:body) { { 'state' => 'FAILED' } }

        it 'does not require checksums in the message' do
          package_update.update(package, message)

          package.reload
          expect(package.state).to eq(PackageModel::FAILED_STATE)
        end
      end

      context 'when the PackageModel is invalid' do
        before do
          allow(package).to receive(:save).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidPackage' do
          expect {
            package_update.update(package, message)
          }.to raise_error(PackageUpdate::InvalidPackage)
        end
      end
    end
  end
end
