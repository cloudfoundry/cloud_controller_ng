require 'spec_helper'
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
        allow(membership).to receive(:admin?).and_return(false)
      end

      it 'returns 200 and updates the package state' do
        code, response = packages_controller.upload(package.guid)

        expect(code).to eq(HTTP::OK)
        expect(response).to eq(expected_response)
        expect(package_presenter).to have_received(:present_json).with(an_instance_of(PackageModel))
        expect(package.reload.state).to eq(PackageModel::PENDING_STATE)
      end

      context 'when app_bits_upload is disabled' do
        before do
          FeatureFlag.make(name: 'app_bits_upload', enabled: false, error_message: nil)
        end

        context 'non-admin user' do
          it 'raises 403' do
            expect {
              packages_controller.upload(package.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'FeatureDisabled'
              expect(error.response_code).to eq 403
              expect(error.message).to match('app_bits_upload')
            end
          end
        end

        context 'admin user' do
          before { allow(membership).to receive(:admin?).and_return(true) }

          it 'returns 200 and updates the package state' do
            code, response = packages_controller.upload(package.guid)

            expect(code).to eq(HTTP::OK)
            expect(response).to eq(expected_response)
            expect(package_presenter).to have_received(:present_json).with(an_instance_of(PackageModel))
            expect(package.reload.state).to eq(PackageModel::PENDING_STATE)
          end
        end
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

    describe '#download' do
      let(:download_location) { 'http://package.download.url' }
      let(:fake_url_generator) { instance_double(CloudController::Blobstore::UrlGenerator) }
      let(:package) { PackageModel.make }
      let(:space) { package.space }
      let(:org) { space.organization }
      let(:file_path) { nil }

      before do
        allow_any_instance_of(PackageDownload).to receive(:download).and_return([file_path, download_location])
        allow(packages_controller).to receive(:check_read_permissions!).and_return(nil)
        package.state = 'READY'
        package.save
      end

      context 'when the package cannot be found' do
        it 'returns 404' do
          expect {
            packages_controller.download('a-bogus-guid')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'permissions' do
        context 'user is an admin' do
          before do
            allow(membership).to receive(:admin?).and_return(true)
          end

          it 'returns 302' do
            response_code, response_headers, _ = packages_controller.download(package.guid)
            expect(response_code).to eq 302
            expect(response_headers['Location']).to eq(download_location)
          end
        end

        context 'user does not have package read permissions' do
          before do
            allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
            allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
          end

          it 'returns 404' do
            expect {
              packages_controller.download(package.guid)
            }.to raise_error do |error|
              expect(error.response_code).to eq 404
              expect(error.name).to eq 'ResourceNotFound'
            end
          end
        end
      end

      context 'when the package is not of type bits' do
        before do
          package.type = 'docker'
          package.save
        end

        it 'returns 422' do
          expect {
            packages_controller.download(package.guid)
          }.to raise_error do |error|
            expect(error.response_code).to eq 422
            expect(error.name).to eq 'UnprocessableEntity'
          end
        end
      end

      context 'when the package has no bits' do
        before do
          package.state = PackageModel::CREATED_STATE
          package.save
        end

        it 'returns 422' do
          expect {
            packages_controller.download(package.guid)
          }.to raise_error do |error|
            expect(error.response_code).to eq 422
            expect(error.name).to eq 'UnprocessableEntity'
          end
        end
      end

      context 'when the package exists on S3' do
        it 'returns 302 and the redirect' do
          code, response_header, _ = packages_controller.download(package.guid)
          expect(code).to eq(302)
          expect(response_header['Location']).to eq(download_location)
        end
      end

      context 'when the package exists on NFS' do
        let(:file_path) { '/a/file/path/on/cc' }
        let(:download_location) { nil }

        it 'begins a download' do
          expect(packages_controller).to receive(:send_file).with(file_path)
          packages_controller.download(package.guid)
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
      let(:req_body) { '{}' }
      let(:package) { PackageModel.make(app_guid: app.guid, type: PackageModel::BITS_TYPE, state: PackageModel::READY_STATE) }
      let(:droplet_response) { 'barbaz' }
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { space.organization }

      before do
        allow(packages_controller).to receive(:check_write_permissions!).and_return(nil)
        allow(droplet_presenter).to receive(:present_json).and_return(droplet_response)
        allow(stagers).to receive(:stager_for_package).and_return(double(:stager, stage: nil))
      end

      it 'returns a 201 Created response' do
        expect {
          response_code, body = packages_controller.stage(package.guid)
          expect(response_code).to eq 201
          expect(body).to eq droplet_response
        }.to change { DropletModel.count }.from(0).to(1)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
            with([Membership::SPACE_DEVELOPER], space.guid,)
      end

      describe 'buildpack request' do
        let(:req_body) { { buildpack: buildpack_request }.to_json }
        let(:buildpack) { Buildpack.make }

        context 'when a git url is requested' do
          let(:buildpack_request) { 'http://dan-and-zach-awesome-pack.com' }

          it 'works with a valid url' do
            response_code, body = packages_controller.stage(package.guid)
            expect(response_code).to eq(201)
            expect(body).to eq droplet_response
            expect(DropletModel.last.buildpack).to eq('http://dan-and-zach-awesome-pack.com')
          end

          context 'when the url is invalid' do
            let(:buildpack_request) { 'totally-broke!' }

            it 'returns a 422' do
              expect {
                packages_controller.stage(package.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end

        context 'when the buildpack is not a url' do
          let(:buildpack_request) { buildpack.name }

          it 'uses buildpack by name' do
            response_code, body = packages_controller.stage(package.guid)
            expect(response_code).to eq(201)
            expect(body).to eq droplet_response
            expect(DropletModel.last.buildpack).to eq(buildpack.name)
          end

          context 'when the buildpack does not exist' do
            let(:buildpack_request) { 'notfound' }

            it 'returns a 422' do
              expect {
                packages_controller.stage(package.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end

        context 'when buildpack is not requsted and app has a buildpack' do
          let(:req_body) { '{}' }

          before do
            app.buildpack = buildpack.name
            app.save
          end

          it 'uses the apps buildpack' do
            response_code, body = packages_controller.stage(package.guid)
            expect(response_code).to eq(201)
            expect(body).to eq droplet_response
            expect(DropletModel.last.buildpack).to eq(app.buildpack)
          end
        end
      end

      context 'when the package does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.stage('made-up-guid')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the stage request includes environment variables' do
        context 'when the environment variables are valid' do
          let(:req_body) {
            '{"environment_variables":
            { "application_version": "whatuuid",
            "application_name": "name-815"}'
          }
          it 'returns a 201' do
            response_code, _ = packages_controller.stage(package.guid)
            expect(response_code).to eq(201)
          end
        end
        context 'when user passes in values to the app' do
          let(:req_body) {
            '{"environment_variables":
            {"key_from_package":"should_merge",
            "conflicting_key":"value_from_package"}'
          }

          before do
            app.environment_variables = { 'key_from_app' => 'should_merge', 'conflicting_key' => 'value_from_app' }
            app.save
          end
          it 'merges with the existing environment variables' do
            response_code, _ = packages_controller.stage(package.guid)
            expect(response_code).to eq(201)
            expect(DropletModel.last.environment_variables).to include('key_from_package' => 'should_merge')
            expect(DropletModel.last.environment_variables).to include('key_from_app' => 'should_merge')
          end
          it 'clobbers the existing value from the app' do
            response_code, _ = packages_controller.stage(package.guid)
            expect(response_code).to eq(201)
            expect(DropletModel.last.environment_variables).to include('conflicting_key' => 'value_from_package')
          end
        end
        context 'when the environment variables are not valid' do
          let(:req_body) { '{"environment_variables":"invalid_param"}' }
          it 'returns a 422' do
            expect {
              packages_controller.stage(package.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq 422
            end
          end
        end
      end

      context 'When the DropletCreateMessage is not valid' do
        let(:req_body) { '{"memory_limit": "invalid"}' }

        it 'returns an UnprocessableEntity error' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
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

      describe 'handling action errors' do
        let(:package_stage_action) { double(PackageStageAction.new) }

        before do
          allow(PackageStageAction).to receive(:new).and_return(package_stage_action)
        end

        context 'when the request package is invalid' do
          before do
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

        context 'when the space quota is exceeded' do
          before do
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

      context 'when the user cannot read the package due to roles' do
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
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user can read but cannot write to the package due to roles' do
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
