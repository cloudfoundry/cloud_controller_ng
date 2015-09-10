require 'spec_helper'
require 'actions/package_copy'

module VCAP::CloudController
  describe PackageCopy do
    let(:package_copy) { PackageCopy.new }

    describe '#copy' do
      let(:target_app) { AppModel.make }
      let(:source_package) { PackageModel.make(type: type, url: url) }
      let(:type) { 'docker' }
      let(:url) { 'docker://cloudfoundry/runtime-ci' }
      let(:app_guid) { target_app.guid }

      it 'creates the package with the correct values' do
        result = package_copy.copy(app_guid, source_package)

        expect(target_app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
        expect(created_package.url).to eq(url)
      end

      describe 'package state' do
        context 'when type is bits' do
          let(:type) { 'bits' }
          let(:url) { nil }

          it 'sets the state to COPYING_STATE' do
            result = package_copy.copy(app_guid, source_package)
            expect(result.type).to eq('bits')
            expect(result.state).to eq(PackageModel::COPYING_STATE)
          end

          it 'enqueues a job to copy the bits in the blobstore' do
            package = nil
            expect {
              package = package_copy.copy(app_guid, source_package)
            }.to change { Delayed::Job.count }.by(1)

            job = Delayed::Job.last
            expect(job.queue).to eq('cc-generic')
            expect(job.handler).to include(package.guid)
            expect(job.handler).to include(source_package.guid)
            expect(job.handler).to include('PackageBitsCopier')
          end
        end

        context 'when the type is docker' do
          it 'sets the state to READY_STATE' do
            result = package_copy.copy(app_guid, source_package)
            expect(result.type).to eq('docker')
            expect(result.state).to eq(PackageModel::READY_STATE)
          end

          it 'does no enqueue a job to copy the bits in the blobstore' do
            expect {
              package_copy.copy(app_guid, source_package)
            }.not_to change { Delayed::Job.count }
          end
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(Steno::Logger).to receive(:info).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an InvalidPackage error' do
          expect {
            package_copy.copy(app_guid, source_package)
          }.to raise_error(PackageCopy::InvalidPackage, 'the message')
        end
      end
    end
  end
end
