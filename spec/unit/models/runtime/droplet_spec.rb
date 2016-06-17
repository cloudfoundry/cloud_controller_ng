require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Droplet, type: :model do
    let(:app) do
      AppFactory.make(droplet_hash: nil)
    end

    let(:blobstore) do
      CloudController::DependencyLocator.instance.droplet_blobstore
    end

    before do
      # force evaluate the blobstore let before stubbing out dependency locator
      blobstore
      allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).
        and_return(blobstore)
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :app }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :app }
      it { is_expected.to validate_presence :droplet_hash }
    end

    it 'creates successfully with an app and a droplet hash' do
      app = AppFactory.make
      expect(Droplet.new(app: app, droplet_hash: Sham.guid).save).to be
    end

    it 'supports long start commands (for mysql compat)' do
      long_start_command = 'o' * 10_000
      droplet = Droplet.make

      expect { droplet.update_detected_start_command(long_start_command) }.to_not raise_error
      expect(droplet.detected_start_command).to eq(long_start_command)
    end

    it 'supports long execution metadata (for mysql compat)' do
      long_execution_metadata = 'o' * 10_000
      droplet = Droplet.make

      expect { droplet.update_execution_metadata(long_execution_metadata) }.to_not raise_error
      expect(droplet.execution_metadata).to eq(long_execution_metadata)
    end

    it 'has a create_at timestamp used in ordering droplets for an app' do
      app.add_new_droplet('hash_1')
      app.save
      expect(app.droplets.first.created_at).to be
    end

    context 'when deleting droplets' do
      it 'destroy drives delete_from_blobstore' do
        app = AppFactory.make
        droplet = app.current_droplet
        enqueuer = double('Enqueuer', enqueue: true)
        expect(Jobs::Enqueuer).to receive(:new) do |job, opts|
          expect(job.new_droplet_key).to eq droplet.new_blobstore_key
          expect(job.old_droplet_key).to eq droplet.old_blobstore_key
          expect(opts[:queue]).to eq 'cc-generic'
        end.and_return(enqueuer)
        droplet.destroy
      end
    end

    describe 'app deletion' do
      it 'deletes the droplet when the app is destroyed' do
        app.add_new_droplet('hash_1')
        app.add_new_droplet('new_hash')
        app.save
        expect(app.droplets).to have(2).items
        expect {
          app.destroy
        }.to change {
          Droplet.count
        }.by(-2)
      end
    end

    describe 'blobstore key' do
      it 'combines app guid and the given digests' do
        expect(Droplet.droplet_key('abc', 'xyz')).to eql('abc/xyz')
      end
    end

    describe 'update_cached_docker_image' do
      let(:docker_image_name) { '10.244.2.6:8080/uuid_generated:latest' }

      context 'when there is no cached_docker_image' do
        let(:droplet) { Droplet.make }

        it 'sets the docker image' do
          expect { droplet.update_cached_docker_image(docker_image_name) }.to_not raise_error
          expect(droplet.cached_docker_image).to eq(docker_image_name)
        end
      end

      context 'when there is an existing cached_docker_image' do
        let(:old_docker_image) { 'cloudfoundry/diego-docker-app:latest' }
        let(:droplet) { Droplet.make(cached_docker_image: old_docker_image) }

        it 'updates the docker image' do
          expect {
            droplet.update_cached_docker_image(docker_image_name)
          }.to change {
            droplet.cached_docker_image
          }.from(old_docker_image).to(docker_image_name)
        end
      end
    end
  end
end
