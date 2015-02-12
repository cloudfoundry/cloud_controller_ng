require 'spec_helper'
require 'handlers/droplets_handler'

module VCAP::CloudController
  describe StagingMessage do
    let(:package_guid) { 'package-guid' }
    let(:memory_limit) { 1024 }

    describe 'create_from_http_request' do
      context 'when the body is valid json' do
        let(:body) { MultiJson.dump({ memory_limit: memory_limit }) }

        it 'creates a StagingMessage from the json' do
          staging_message = StagingMessage.create_from_http_request(package_guid, body)
          valid, errors   = staging_message.validate

          expect(valid).to be_truthy
          expect(errors).to be_empty
        end
      end

      context 'when the body is not valid json' do
        let(:body) { '{{' }

        it 'returns a StagingMessage that is not valid' do
          staging_message = StagingMessage.create_from_http_request(package_guid, body)
          valid, errors   = staging_message.validate

          expect(valid).to be_falsey
          expect(errors[0]).to include('parse error')
        end
      end
    end

    context 'when only required fields are provided' do
      let(:body) { '{}' }

      it 'is valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_truthy
        expect(errors).to be_empty
      end

      it 'provides default values' do
        psm = StagingMessage.create_from_http_request(package_guid, body)

        expect(psm.memory_limit).to eq(1024)
        expect(psm.disk_limit).to eq(4096)
        expect(psm.stack).to eq(Stack.default.name)
      end
    end

    context 'when memory_limit is not an integer' do
      let(:body) { MultiJson.dump({ memory_limit: 'stringsarefun' }) }

      it 'is not valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_falsey
        expect(errors[0]).to include('must be an Integer')
      end
    end

    context 'when disk_limit is not an integer' do
      let(:body) { MultiJson.dump({ disk_limit: 'stringsarefun' }) }

      it 'is not valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_falsey
        expect(errors[0]).to include('must be an Integer')
      end
    end

    context 'when stack is not a string' do
      let(:body) { MultiJson.dump({ stack: 1024 }) }

      it 'is not valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_falsey
        expect(errors[0]).to include('must be a String')
      end
    end

    context 'when buildpack_git_url is not a valid url' do
      let(:body) { MultiJson.dump({ buildpack_git_url: 'blagow!' }) }

      it 'is not valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_falsey
        expect(errors[0]).to include('must be a valid URI')
      end
    end

    context 'when buildpack_guid is not a string' do
      let(:body) { MultiJson.dump({ buildpack_guid: 1024 }) }

      it 'is not valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_falsey
        expect(errors[0]).to include('must be a String')
      end
    end

    context 'when both buildpack_git_url and buildpack_guid are provided' do
      let(:body) { MultiJson.dump({ buildpack_guid: 'some-guid', buildpack_git_url: 'http://www.slashdot.org' }) }

      it 'is not valid' do
        psm           = StagingMessage.create_from_http_request(package_guid, body)
        valid, errors = psm.validate
        expect(valid).to be_falsey
        expect(errors[0]).to include('Only one of buildpack_git_url or buildpack_guid may be provided')
      end
    end
  end

  describe DropletsHandler do
    let(:config) { TestConfig.config }
    let(:stagers) { double(:stagers) }
    let(:droplets_handler) { described_class.new(config, stagers) }
    let(:user) { User.make }
    let(:access_context) { double(:access_context) }

    before do
      allow(access_context).to receive(:cannot?).and_return(false)
      allow(access_context).to receive(:user).and_return(user)
    end

    describe '#list' do
      let(:space) { Space.make }
      let(:package) { PackageModel.make(space_guid: space.guid) }
      let!(:droplet1) { DropletModel.make(package_guid: package.guid) }
      let!(:droplet2) { DropletModel.make(package_guid: package.guid) }
      let(:user) { User.make }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:options) { { page: page, per_page: per_page } }
      let(:pagination_options) { PaginationOptions.new(options) }
      let(:paginator) { double(:paginator) }

      let(:handler) { described_class.new(nil, nil, paginator) }
      let(:roles) { double(:roles, admin?: admin_role) }
      let(:admin_role) { false }

      before do
        allow(access_context).to receive(:roles).and_return(roles)
        allow(access_context).to receive(:user).and_return(user)
        allow(paginator).to receive(:get_page)
      end

      context 'when the user is an admin' do
        let(:admin_role) { true }
        before do
          allow(access_context).to receive(:roles).and_return(roles)
          DropletModel.make
        end

        it 'allows viewing all droplets' do
          handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(3)
          end
        end
      end

      context 'when the user cannot list any droplets' do
        it 'applies a user visibility filter properly' do
          handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(0)
          end
        end
      end

      context 'when the user can list droplets' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
          DropletModel.make
        end

        it 'applies a user visibility filter properly' do
          handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(2)
          end
        end
      end
    end

    describe '#create' do
      let(:app_model) { AppModel.make }
      let(:app_guid) { app_model.guid }
      let(:space) { Space.make }
      let(:package) { PackageModel.make(app_guid: app_guid, space_guid: space.guid, state: PackageModel::READY_STATE, type: PackageModel::BITS_TYPE) }
      let(:package_guid) { package.guid }
      let(:stack) { 'trusty32' }
      let(:memory_limit) { 12340 }
      let(:disk_limit) { 32100 }
      let(:disk_limit) { 32100 }
      let(:buildpack_guid) { nil }
      let(:buildpack_key) { nil }
      let(:buildpack_git_url) { 'something' }
      let(:body) do
        {
          stack:             stack,
          memory_limit:      memory_limit,
          disk_limit:        disk_limit,
          buildpack_guid:    buildpack_guid,
          buildpack_git_url: buildpack_git_url,
        }.stringify_keys
      end
      let(:staging_message) { StagingMessage.new(package_guid, body) }
      let(:stager) { double(:stager) }

      before do
        allow(stagers).to receive(:stager_for_package).with(package).and_return(stager)
        allow(stager).to receive(:stage_package)
      end

      context 'when the package exists' do
        context 'and the user is a space developer' do
          let(:buildpack) { Buildpack.make }
          let(:buildpack_guid) { buildpack.guid }
          let(:buildpack_key) { buildpack.key }

          it 'creates a droplet' do
            droplet = nil
            expect {
              droplet = droplets_handler.create(staging_message, access_context)
            }.to change(DropletModel, :count).by(1)
            expect(droplet.state).to eq(DropletModel::PENDING_STATE)
            expect(droplet.package_guid).to eq(package_guid)
            expect(droplet.buildpack_git_url).to eq('something')
            expect(droplet.buildpack_guid).to eq(buildpack_guid)
            expect(droplet.app_guid).to eq(app_guid)
          end

          it 'initiates a staging request' do
            droplets_handler.create(staging_message, access_context)
            droplet = DropletModel.last
            expect(stager).to have_received(:stage_package).with(droplet, stack, memory_limit, disk_limit, buildpack_key, buildpack_git_url)
          end
        end

        context 'and the user is not a space developer' do
          before do
            allow(access_context).to receive(:cannot?).and_return(true)
          end

          it 'fails with Unauthorized' do
            expect {
              droplets_handler.create(staging_message, access_context)
            }.to raise_error(DropletsHandler::Unauthorized)
            expect(access_context).to have_received(:cannot?).with(:create, kind_of(DropletModel), space)
          end
        end
      end

      context 'when the package type is not bits' do
        before do
          package.update(type: PackageModel::DOCKER_TYPE)
        end

        it 'fails with InvalidRequest' do
          expect {
            droplets_handler.create(staging_message, access_context)
          }.to raise_error(DropletsHandler::InvalidRequest)
        end
      end

      context 'when the package is not ready' do
        before do
          package.update(state: PackageModel::CREATED_STATE)
        end

        it 'fails with InvalidRequest' do
          expect {
            droplets_handler.create(staging_message, access_context)
          }.to raise_error(DropletsHandler::InvalidRequest)
        end
      end

      context 'when the package does not exist' do
        let(:package_guid) { 'non-existant' }

        it 'fails with PackageNotFound' do
          expect {
            droplets_handler.create(staging_message, access_context)
          }.to raise_error(DropletsHandler::PackageNotFound)
        end
      end

      context 'when the space does not exist' do
        before do
          package # just so it gets created
          space.destroy
        end

        it 'fails with SpaceNotFound' do
          expect {
            droplets_handler.create(staging_message, access_context)
          }.to raise_error(DropletsHandler::SpaceNotFound)
        end
      end

      context 'when a specific admin buildpack is requested' do
        context 'and the buildpack exists' do
          let(:buildpack) { Buildpack.make }
          let(:buildpack_guid) { buildpack.guid }
          let(:buildpack_key) { buildpack.key }

          it 'initiates the correct staging request' do
            droplets_handler.create(staging_message, access_context)
            droplet = DropletModel.last
            expect(stager).to have_received(:stage_package).with(droplet, stack, memory_limit, disk_limit, buildpack_key, buildpack_git_url)
          end
        end

        context 'and the buildpack does not exist' do
          let(:buildpack_guid) { 'not-real' }

          it 'raises BuildpackNotFound' do
            expect {
              droplets_handler.create(staging_message, access_context)
            }.to raise_error(DropletsHandler::BuildpackNotFound)
          end
        end
      end
    end

    describe 'show' do
      context 'when the droplet exists' do
        let(:droplet) { DropletModel.make }
        let(:droplet_guid) { droplet.guid }

        context 'and the user has permissions to read' do
          it 'returns the droplet' do
            expect(access_context).to receive(:cannot?).and_return(false)
            expect(droplets_handler.show(droplet_guid, access_context)).to eq(droplet)
          end
        end

        context 'and the user does not have permissions to read' do
          it 'raises an Unathorized exception' do
            expect(access_context).to receive(:cannot?).and_return(true)
            expect {
              droplets_handler.show(droplet_guid, access_context)
            }.to raise_error(DropletsHandler::Unauthorized)
          end
        end
      end

      context 'when the droplet does not exist' do
        it 'returns nil' do
          expect(access_context).not_to receive(:cannot?)
          expect(droplets_handler.show('bogus-droplet', access_context)).to be_nil
        end
      end
    end

    describe '#delete' do
      context 'when the droplet exists' do
        let(:space) { Space.make }
        let(:package) { PackageModel.make(space_guid: space.guid) }
        let!(:droplet) { DropletModel.make(package_guid: package.guid, droplet_hash: 'jim') }
        let(:droplet_guid) { droplet.guid }

        context 'and the user has permissions to delete the droplet' do
          it 'allows filter by guid' do
            expect(access_context).to receive(:cannot?).and_return(false)
            expect {
              expect(droplets_handler.delete(access_context, filter: { guid: droplet_guid })).to eq([droplet])
            }.to change { DropletModel.count }.by(-1)
            expect(droplets_handler.show(droplet_guid, access_context)).to be_nil
          end

          it 'allows filter by app_guid' do
            expect(access_context).to receive(:cannot?).and_return(false)
            expect {
              expect(droplets_handler.delete(access_context, filter: { app_guid: droplet.app_guid })).to eq([droplet])
            }.to change { DropletModel.count }.by(-1)
            expect(droplets_handler.show(droplet_guid, access_context)).to be_nil
          end

          it 'prevents filtering on other fields' do
            expect(access_context).to receive(:cannot?).and_return(false)
            expect {
              expect(droplets_handler.delete(access_context, filter: { torpedo: 'speedo' })).to be_empty
            }.not_to change { DropletModel.count }
            expect(droplets_handler.show(droplet_guid, access_context)).to eq(droplet)
          end

          it 'enqueues a job to delete the corresponding blob from the blobstore' do
            job_opts = { queue: 'cc-generic' }

            expect(BlobstoreDelete).to receive(:new).
              with(File.join(droplet.guid, droplet.droplet_hash), :droplet_blobstore, nil).
              and_call_original

            expect(Jobs::Enqueuer).to receive(:new).with(kind_of(BlobstoreDelete), job_opts).
              and_call_original

            expect {
              droplets_handler.delete(access_context, filter: { guid: droplet_guid })
            }.to change { Delayed::Job.count }.by(1)
          end
        end

        context 'and the user does not have permissions to delete the droplet' do
          it 'raises an Unauthorized exception' do
            expect(access_context).to receive(:cannot?).and_return(true)
            expect {
              expect {
                droplets_handler.delete(access_context, filter: { guid: droplet_guid })
              }.to raise_error(DropletsHandler::Unauthorized)
            }.not_to change { DropletModel.count }
          end
        end
      end

      context 'when the droplet does not exist' do
        it 'returns nil' do
          expect(access_context).to_not receive(:cannot?)
          expect(droplets_handler.delete(access_context, filter: { guid: 'bogus-droplet' })).to be_empty
        end
      end
    end
  end
end
