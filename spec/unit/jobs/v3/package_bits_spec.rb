require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe PackageBits do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:package_guid) { SecureRandom.uuid }

      subject(:job) do
        PackageBits.new(package_guid, uploaded_path)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:package_blobstore) { double(:package_blobstore) }
        let(:tmpdir) { '/tmp/special_temp' }
        let(:max_package_size) { 256 }

        before do
          TestConfig.override({ directories: { tmpdir: tmpdir }, packages: TestConfig.config[:packages].merge(max_package_size: max_package_size) })

          allow(AppBitsPackage).to receive(:new) { double(:packer, create_package_in_blobstore: 'done') }
        end

        it 'creates an AppBitsPackage and performs' do
          packer = double(:packer)
          expect(AppBitsPackage).to receive(:new).and_return(packer)
          expect(packer).to receive(:create_package_in_blobstore).with(package_guid, uploaded_path)
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:package_bits)
        end

        it 'expires any old packages' do
        end
      end
    end
  end
end
