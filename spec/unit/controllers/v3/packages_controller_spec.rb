require 'spec_helper'
require 'queries/package_stage_fetcher'
require 'actions/package_stage_action'

module VCAP::CloudController
  describe PackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:params) { {} }
    let(:package_presenter) { double(:package_presenter) }
    let(:droplet_presenter) { double(:droplet_presenter) }
    let(:membership) { double(:membership) }
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
          package_presenter: package_presenter,
          droplet_presenter: droplet_presenter,
          stagers: stagers,
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(packages_controller).to receive(:membership).and_return(membership)
    end

    describe '#upload' do
      let(:package) { PackageModel.make }
      let(:space) { package.space }
      let(:org) { space.organization }
      let(:params) { { 'bits_path' => 'path/to/bits' } }
      let(:expected_response) { 'response stuff' }

      before do
        allow(package_presenter).to receive(:present_json).and_return(expected_response)
        allow(packages_controller).to receive(:check_write_permissions!)
      end

      it 'returns 200 and updates the package state' do
        code, response = packages_controller.upload(package.guid)

        expect(code).to eq(HTTP::OK)
        expect(response).to eq(expected_response)
        expect(package_presenter).to have_received(:present_json).with(an_instance_of(PackageModel))
        expect(package.reload.state).to eq(PackageModel::PENDING_STATE)
      end

      context 'when the package type is not bits' do
        before do
          package.type = 'docker'
          package.save
        end

        it 'returns a 422 Unprocessable' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
            expect(error.message).to include('Package type must be bits.')
          end
        end
      end

      context 'when the package does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.upload('not-real')
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

      context 'when the user does not have write scope' do
        before do
          allow(packages_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
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

      context 'when the user cannot read the package' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user does not have correct roles to upload' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], space.guid).and_return(false)
        end

        it 'returns a 403' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with([Membership::SPACE_DEVELOPER], space.guid)
        end
      end

      context 'when the bits have already been uploaded' do
        before do
          package.state = PackageModel::READY_STATE
          package.save
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

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(PackageUpload).to receive(:upload).and_raise(PackageUpload::InvalidPackage.new('err'))
        end

        it 'returns 422' do
          expect {
            packages_controller.upload(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end
    end

    describe '#show' do
      let(:package) { PackageModel.make }
      let(:space) { package.space }
      let(:org) { space.organization }
      let(:package_guid) { package.guid }

      let(:expected_response) { 'im a response' }

      before do
        allow(package_presenter).to receive(:present_json).and_return(expected_response)
        allow(packages_controller).to receive(:check_read_permissions!).and_return(nil)
      end

      it 'returns a 200 OK and the package' do
        response_code, response = packages_controller.show(package.guid)
        expect(response_code).to eq 200
        expect(response).to eq(expected_response)
        expect(package_presenter).to have_received(:present_json).with(package)
      end

      context 'when the user has the incorrect scope' do
        before do
          allow(packages_controller).to receive(:check_read_permissions!).
            and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            packages_controller.show(package_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(packages_controller).to have_received(:check_read_permissions!)
        end
      end

      context 'when the user has incorrect roles' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 not found' do
          expect {
            packages_controller.show(package_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
          expect(membership).to have_received(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid)
        end
      end

      context 'when the package does not exist' do
        it 'returns a 404 Not Found' do
          expect {
            packages_controller.show('non-existant')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe '#delete' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }

      before do
        allow(packages_controller).to receive(:check_write_permissions!)
      end

      it 'checks for write permissions' do
        packages_controller.delete(package.guid)
        expect(packages_controller).to have_received(:check_write_permissions!)
      end

      it 'checks for the proper roles' do
        packages_controller.delete(package.guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
          with([Membership::SPACE_DEVELOPER], space.guid)
      end

      it 'returns a 204 NO CONTENT' do
        response_code, response = packages_controller.delete(package.guid)
        expect(response_code).to eq 204
        expect(response).to be_nil
      end

      context 'when the user cannot read the package' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.delete(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user can read but cannot write to the package' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).
            and_return(true)
          allow(membership).to receive(:has_any_roles?).with([Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          expect {
            packages_controller.delete(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
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
      let(:expected_response) { 'im a response' }

      before do
        allow(package_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(packages_controller).to receive(:check_read_permissions!).and_return(nil)
        allow(membership).to receive(:admin?)
        allow(membership).to receive(:space_guids_for_roles)
      end

      it 'returns 200 and lists the packages' do
        response_code, response_body = packages_controller.list

        expect(package_presenter).to have_received(:present_json_list).with(an_instance_of(PaginatedResult), '/v3/packages')
        expect(response_code).to eq(200)
        expect(response_body).to eq(expected_response)
      end

      context 'when the user has the incorrect scope' do
        before do
          allow(packages_controller).to receive(:check_read_permissions!).
            and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            packages_controller.list
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(packages_controller).to have_received(:check_read_permissions!)
        end
      end

      context 'when the user is an admin' do
        before do
          allow(membership).to receive(:admin?).and_return(true)
        end

        it 'returns all packages' do
          PackageModel.make
          PackageModel.make
          PackageModel.make

          response_code, response_body = packages_controller.list

          expect(package_presenter).to have_received(:present_json_list).
            with(an_instance_of(PaginatedResult), '/v3/packages') do |result|
              expect(result.total).to eq(PackageModel.count)
            end
          expect(response_code).to eq(200)
          expect(response_body).to eq(expected_response)
        end
      end

      context 'when the user is not an admin' do
        let(:viewable_package) { PackageModel.make }

        before do
          allow(membership).to receive(:admin?).and_return(false)
          allow(membership).to receive(:space_guids_for_roles).and_return([viewable_package.app.space.guid])
        end

        it 'returns packages the user has roles to see' do
          PackageModel.make
          PackageModel.make

          response_code, response_body = packages_controller.list

          expect(package_presenter).to have_received(:present_json_list).
            with(an_instance_of(PaginatedResult), '/v3/packages') do |result|
              expect(result.total).to be < PackageModel.count
              expect(result.total).to eq(1)
            end
          expect(response_code).to eq(200)
          expect(response_body).to eq(expected_response)
          expect(membership).to have_received(:space_guids_for_roles).
            with([Membership::SPACE_DEVELOPER,
                  Membership::SPACE_MANAGER,
                  Membership::SPACE_AUDITOR,
                  Membership::ORG_MANAGER])
        end
      end

      context 'when parameters are invalid' do
        context 'because there are unknown parameters' do
          let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

          it 'returns an 400 Bad Request' do
            expect {
              packages_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include("Unknown query param(s) 'invalid', 'bad'")
            end
          end
        end

        context 'because there are invalid values in parameters' do
          let(:params) { { 'per_page' => 'foo' } }

          it 'returns an 400 Bad Request' do
            expect {
              packages_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include('Per page must be between 1 and 5000')
            end
          end
        end
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
        allow(packages_controller).to receive(:check_write_permissions!).and_return(nil)
        allow(droplet_presenter).to receive(:present_json).and_return(droplet_response)
        allow(package_stage_fetcher).to receive(:fetch).with(package.guid, buildpack.guid).and_return([package, app, space, org, buildpack])
        allow(package_stage_action).to receive(:stage).and_return(droplet)
      end

      it 'checks for the proper roles' do
        packages_controller.stage(package.guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
          with([Membership::SPACE_DEVELOPER], space.guid,)
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
              package, app, space, org, nil, an_instance_of(DropletCreateMessage), stagers)
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
              package, app, space, org, buildpack, an_instance_of(DropletCreateMessage), stagers)
          end

          context 'when the DropletCreateMessage is not valid' do
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

      context 'when the user does not have the write scope' do
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

      context 'when the user cannot read the package due to roles' do
        before do
          allow(package_stage_fetcher).to receive(:fetch).and_return([package, app, space, org, buildpack])
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
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

      context 'when the user can read but cannot write to the package due to roles' do
        before do
          allow(package_stage_fetcher).to receive(:fetch).and_return([package, app, space, org, buildpack])
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).
             and_return(true)
          allow(membership).to receive(:has_any_roles?).with([Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the request body is invalid JSON' do
        let(:req_body) { '{ invalid_json }' }

        it 'returns an 400 Bad Request' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end
    end
  end
end
