require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackDelete do
      subject(:job) { described_class.new(guid: buildpack_guid, timeout: timeout) }
      let(:buildpack_guid) { buildpack.guid }
      let(:timeout) { 90000 }

      let(:buildpack) { VCAP::CloudController::Buildpack.create({ name: 'first_buildpack', key: 'xyz', position: 1 }) }

      before do
        allow(BuildpackBitsDelete).to receive(:delete_when_safe)
      end

      it 'deletes the buildpack from the database' do
        job.perform
        expect(Buildpack.find(name: buildpack.name)).to be_nil
      end

      it 'enqueues a job to delete the buildpack from the blobstore' do
        job.perform

        expect(BuildpackBitsDelete).to have_received(:delete_when_safe).with(buildpack.key, 90000)
      end

      context 'when the buildpack does not exist' do
        let(:buildpack_guid) { 'made-up-guid' }

        it 'does not enqueue a job to delete the buildpack from the blobstore' do
          job.perform

          expect(BuildpackBitsDelete).not_to have_received(:delete_when_safe)
        end
      end

      context 'when deleting the buildpack from the database fails' do
        before do
          fake_model_deletion = instance_double(ModelDeletion, perform: false)
          allow(ModelDeletion).to receive(:new).with(buildpack.class, buildpack.guid).and_return(fake_model_deletion)
        end

        it 'does not enqueue a job to delete the buildpack from the blobstore' do
          job.perform

          expect(BuildpackBitsDelete).not_to have_received(:delete_when_safe)
        end
      end
    end
  end
end
