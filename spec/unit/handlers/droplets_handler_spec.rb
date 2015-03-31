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
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let!(:droplet1) { DropletModel.make(app_guid: app_model.guid) }
      let!(:droplet2) { DropletModel.make(app_guid: app_model.guid) }
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
  end
end
