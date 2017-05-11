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
          }.to raise_error(PackageUpdate::InvalidPackage)
        end
      end

      context 'when the package is already in FAILED_STATE' do
        let(:package) { PackageModel.make(state: PackageModel::FAILED_STATE) }

        it 'raises InvalidPackage' do
          expect {
            package_update.update(package, message)
          }.to raise_error(PackageUpdate::InvalidPackage)
        end
      end

      context 'when the package is invalid' do
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
