require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe DropletBitsCopier do
      subject(:job) { DropletBitsCopier.new(source_droplet.guid, destination_droplet.guid) }

      let(:droplet_bits_path) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:blobstore_dir) { Dir.mktmpdir }
      let(:droplet_blobstore) do
        CloudController::Blobstore::FogClient.new(connection_config: { provider: 'Local', local_root: blobstore_dir },
                                                  directory_key: 'droplet')
      end
      let(:source_droplet) { DropletModel.make(:buildpack, droplet_hash: 'abcdef1234') }
      let(:destination_droplet) { DropletModel.make(:buildpack, state: DropletModel::PENDING_STATE) }

      before do
        Fog.unmock!
      end

      after do
        Fog.mock!
        FileUtils.remove_entry_secure blobstore_dir
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:droplet_bits_copier)
      end

      describe '#perform' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(droplet_blobstore)
          droplet_blobstore.cp_to_blobstore(droplet_bits_path, source_droplet.blobstore_key)
        end

        it 'copies the source droplet zip to the droplet blob store for the destination droplet' do
          expect(droplet_blobstore.exists?(destination_droplet.guid)).to be false

          job.perform

          expect(droplet_blobstore.exists?(destination_droplet.reload.blobstore_key)).to be true
        end

        it 'updates the destination droplet_hash and state' do
          expect(destination_droplet.droplet_hash).to be nil
          expect(destination_droplet.state).not_to eq(source_droplet.state)

          job.perform

          destination_droplet.reload
          expect(destination_droplet.droplet_hash).to eq(source_droplet.droplet_hash)
          expect(destination_droplet.state).to eq(source_droplet.state)
        end

        context 'when the copy fails' do
          before do
            allow(droplet_blobstore).to receive(:cp_file_between_keys).and_raise('ba boom!')
          end

          it 'marks the droplet as failed and saves the message and raises the error' do
            expect(destination_droplet.error).to be nil

            expect { job.perform }.to raise_error('ba boom!')

            destination_droplet.reload
            expect(destination_droplet.error).to eq('failed to copy - ba boom!')
            expect(destination_droplet.state).to eq(VCAP::CloudController::DropletModel::FAILED_STATE)
          end
        end

        context 'when the source droplet does not exist' do
          before { source_droplet.destroy }

          it 'marks the droplet as failed and saves the message and raises the error' do
            expect(destination_droplet.error).to be nil

            expect { job.perform }.to raise_error('source droplet does not exist')

            destination_droplet.reload
            expect(destination_droplet.error).to eq('failed to copy - source droplet does not exist')
            expect(destination_droplet.state).to eq(VCAP::CloudController::DropletModel::FAILED_STATE)
          end
        end

        context 'when the destination droplet does not exist' do
          before { destination_droplet.destroy }

          it 'marks the droplet as failed and saves the message and raises the error' do
            expect { job.perform }.to raise_error('destination droplet does not exist')
          end
        end
      end
    end
  end
end
