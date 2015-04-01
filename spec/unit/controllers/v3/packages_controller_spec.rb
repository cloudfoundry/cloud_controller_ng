require 'spec_helper'
require 'queries/package_stage_fetcher'
require 'actions/package_stage_action'

module VCAP::CloudController
  describe PackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:params) { {} }
    let(:packages_handler) { double(:packages_handler) }
    let(:apps_handler) { double(:apps_handler) }
    let(:package_presenter) { double(:package_presenter) }
    let(:droplet_presenter) { double(:droplet_presenter) }
    let(:stagers) { double(:stagers) }
    let(:req_body) { '{}' }

    let(:packages_controller) do
      PackagesController.new(
        {},
        logger,
        {},
        params.stringify_keys,
        req_body,
        nil,
        {
          packages_handler: packages_handler,
          package_presenter: package_presenter,
          droplet_presenter: droplet_presenter,
          apps_handler: apps_handler,
          stagers: stagers,
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
    end

    describe '#upload' do
      let(:package) { PackageModel.make }
      let(:params) { { 'bits_path' => 'path/to/bits' } }

      context 'when the package type is not bits' do
        before do
          allow(packages_handler).to receive(:upload).and_raise(PackagesHandler::InvalidPackageType)
        end

        it 'returns a 400 InvalidRequest' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'InvalidRequest'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the package does not exist' do
        before do
          allow(packages_handler).to receive(:upload).and_raise(PackagesHandler::PackageNotFound)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the message is not valid' do
        let(:params) { {} }

        it 'returns a 422 UnprocessableEntity error' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end

      context 'when the user cannot access the package' do
        before do
          allow(packages_handler).to receive(:upload).and_raise(PackagesHandler::Unauthorized)
        end

        it 'returns an Unauthorized error' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the bits have already been uploaded' do
        before do
          allow(packages_handler).to receive(:upload).and_raise(PackagesHandler::BitsAlreadyUploaded)
        end
        it 'returns a 400 PackageBitsAlreadyUploaded error' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'PackageBitsAlreadyUploaded'
            expect(error.response_code).to eq 400
          end
        end
      end
    end

    describe '#show' do
      context 'when the package does not exist' do
        before do
          allow(packages_handler).to receive(:show).and_return(nil)
        end

        it 'returns a 404 Not Found' do
          expect {
            packages_controller.show('non-existant')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the package exists' do
        let(:package) { PackageModel.make }
        let(:package_guid) { package.guid }

        context 'when a user can access a package' do
          let(:expected_response) { 'im a response' }

          before do
            allow(packages_handler).to receive(:show).and_return(package)
            allow(package_presenter).to receive(:present_json).and_return(expected_response)
          end

          it 'returns a 200 OK and the package' do
            response_code, response = packages_controller.show(package.guid)
            expect(response_code).to eq 200
            expect(response).to eq(expected_response)
          end
        end

        context 'when the user cannot access the package' do
          before do
            allow(packages_handler).to receive(:show).and_raise(PackagesHandler::Unauthorized)
          end

          it 'returns a 403 NotAuthorized error' do
            expect {
              packages_controller.show(package_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end
      end
    end

    describe '#delete' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }

      before do
        # stubbing the BaseController methods for now, this should probably be
        # injected into the packages controller
        allow(packages_controller).to receive(:current_user).and_return(user)
        allow(packages_controller).to receive(:check_write_permissions!)

        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'checks for write permissions' do
        packages_controller.delete(package.guid)
        expect(packages_controller).to have_received(:check_write_permissions!)
      end

      context 'when the package exists' do
        context 'when a user can access a package' do
          it 'returns a 204 NO CONTENT' do
            response_code, response = packages_controller.delete(package.guid)
            expect(response_code).to eq 204
            expect(response).to be_nil
          end
        end

        context 'when the user cannot access the package' do
          before do
            allow(packages_controller).to receive(:current_user).and_return(User.make)
          end

          it 'returns a 404 NotFound error' do
            expect {
              packages_controller.delete(package.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end
      end

      context 'when the package does not exist' do
        it 'returns a 404 Not Found' do
          expect {
            packages_controller.delete('non-existant')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:list_response) { 'list_response' }
      let(:expected_response) { 'im a response' }

      before do
        allow(package_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(packages_handler).to receive(:list).and_return(list_response)
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = packages_controller.list

        expect(packages_handler).to have_received(:list)
        expect(package_presenter).to have_received(:present_json_list).with(list_response, '/v3/packages')
        expect(response_code).to eq(200)
        expect(response_body).to eq(expected_response)
      end
    end

    describe '#stage' do
      let(:req_body)  { '{"buildpack_guid":"' + buildpack.guid + '"}' }
      let(:package) { PackageModel.make }
      let(:droplet_response) { 'barbaz' }
      let(:package_stage_fetcher) { double(:package_stage_fetcher) }
      let(:package_stage_action) { double(:package_stage_action) }
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { space.organization }
      let(:droplet) { DropletModel.make }
      let(:buildpack) { Buildpack.make }

      before do
        allow(packages_controller).to receive(:package_stage_fetcher).and_return(package_stage_fetcher)
        allow(packages_controller).to receive(:package_stage_action).and_return(package_stage_action)
        allow(packages_controller).to receive(:current_user).and_return(user)
        allow(packages_controller).to receive(:check_write_permissions!).and_return(nil)
        allow(droplet_presenter).to receive(:present_json).and_return(droplet_response)
      end

      context 'when the buildpack does not exist' do
        context 'and is requested' do
          before do
            allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([package, app, space, org, nil])
          end

          it 'returns a 404 ResourceNotFound error' do
            expect {
              packages_controller.stage(package.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'and is not requested' do
          let(:req_body)  { '{}' }

          before do
            allow(package_stage_fetcher).to receive(:fetch).with(package.guid, nil).and_return([package, app, space, org, nil])
            allow(package_stage_action).to receive(:stage).and_return(droplet)
          end

          it 'returns a 201 Created response' do
            response_code, body = packages_controller.stage(package.guid)
            expect(response_code).to eq 201
            expect(body).to eq droplet_response
            expect(package_stage_action).to have_received(:stage).with(
              package, app, space, org, nil, an_instance_of(StagingMessage), stagers)
          end
        end
      end

      context 'when the package does not exist' do
        before do
          allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([nil, app, space, org, nil])
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does not exist' do
        before do
          allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([package, nil, space, org, buildpack])
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the space does not exist' do
        before do
          allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([package, app, nil, org, buildpack])
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when all the dependencies exists' do
        context 'and the user is a space developer' do
          before do
            allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([package, app, space, org, buildpack])
            allow(package_stage_action).to receive(:stage).and_return(droplet)
          end

          it 'returns a 201 Created response' do
            response_code, body = packages_controller.stage(package.guid)
            expect(response_code).to eq 201
            expect(body).to eq droplet_response
            expect(package_stage_action).to have_received(:stage).with(
              package, app, space, org, buildpack, an_instance_of(StagingMessage), stagers)
          end

          context 'when the StagingMessage is not valid' do
            let(:req_body) { '{"memory_limit":"invalid"}' }

            it 'returns an UnprocessableEntity error' do
              expect {
                packages_controller.stage(package.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end
      end

      context 'when the request package is invalid' do
        before do
          allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([package, app, space, org, buildpack])
          allow(package_stage_action).to receive(:stage).and_raise(PackageStageAction::InvalidPackage)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'InvalidRequest'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the user cannot access the droplet' do
        it 'raises an ApiError with a 403 code' do
          expect(packages_controller).to receive(:check_write_permissions!).
            and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

     context 'when the space quota is exceeded' do
       before do
         allow(package_stage_fetcher).to receive(:fetch).and_return([package, app, space, org, buildpack])
         allow(package_stage_action).to receive(:stage).and_raise(PackageStageAction::SpaceQuotaExceeded)
       end

       it 'raises ApiError UnableToPerform' do
         expect {
           packages_controller.stage(package.guid)
         }.to raise_error do |error|
           expect(error.name).to eq 'UnableToPerform'
           expect(error.response_code).to eq 400
           expect(error.message).to include('Staging request')
           expect(error.message).to include("space's memory limit exceeded")
         end
       end
     end

     context 'when the org quota is exceeded' do
       before do
         allow(package_stage_fetcher).to receive(:fetch).and_return([package, app, space, org, buildpack])
         allow(package_stage_action).to receive(:stage).and_raise(PackageStageAction::OrgQuotaExceeded)
       end

       it 'raises ApiError UnableToPerform' do
         expect {
           packages_controller.stage(package.guid)
         }.to raise_error do |error|
           expect(error.name).to eq 'UnableToPerform'
           expect(error.response_code).to eq 400
           expect(error.message).to include('Staging request')
           expect(error.message).to include("organization's memory limit exceeded")
         end
       end
     end

     context 'when the disk limit is exceeded' do
       before do
         allow(package_stage_fetcher).to receive(:fetch).and_return([package, app, space, org, buildpack])
         allow(package_stage_action).to receive(:stage).and_raise(PackageStageAction::DiskLimitExceeded)
       end

       it 'raises ApiError UnableToPerform' do
         expect {
           packages_controller.stage(package.guid)
         }.to raise_error do |error|
           expect(error.name).to eq 'UnableToPerform'
           expect(error.response_code).to eq 400
           expect(error.message).to include('Staging request')
           expect(error.message).to include('disk limit exceeded')
         end
       end
     end
    end
  end
end
