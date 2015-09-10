require 'spec_helper'

module VCAP::CloudController
  describe AppsPackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:package_presenter) { double(:package_presenter) }
    let(:app) { nil }
    let(:membership) { double(:membership) }
    let(:controller) do
      AppsPackagesController.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          package_presenter: package_presenter
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(controller).to receive(:current_user).and_return(User.make)
      allow(controller).to receive(:membership).and_return(membership)
    end

    describe '#create_new' do
      let(:app) { AppModel.make }
      let(:app_guid) { app.guid }
      let(:space) { app.space }
      let(:org) { space.organization }
      let(:req_body) { '{"type":"bits"}' }

      let(:package_response) { 'foobar' }

      before do
        allow(package_presenter).to receive(:present_json).and_return(package_response)
        allow(controller).to receive(:check_write_permissions!).and_return(nil)
        allow(membership).to receive(:has_any_roles?).and_return(true)
      end

      it 'returns a 201 and the response' do
        expect(app.packages.count).to eq(0)

        response_code, response = controller.create_new(app_guid)

        expect(response_code).to eq 201
        expect(package_presenter).to have_received(:present_json).with(an_instance_of(PackageModel))
        expect(response).to eq(package_response)

        app.reload
        package = app.packages.first
        expect(package.type).to eq('bits')
      end

      context 'with invalid json' do
        let(:req_body) { '{{' }

        it 'returns an UnprocessableEntity error' do
          expect {
            controller.create_new(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'with an invalid type field' do
        let(:req_body) { '{ "type": "ninja" }' }

        it 'returns an UnprocessableEntity error' do
          expect {
            controller.create_new(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end

      context 'when the user does not have write scope' do
        before do
          allow(controller).to receive(:check_write_permissions!).and_raise(
            VCAP::Errors::ApiError.new_from_details('NotAuthorized')
          )
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            controller.create_new(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.create_new('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the app' do
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
            controller.create_new(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot create the package' do
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

        it 'returns a 403 NotAuthorized error' do
          expect {
            controller.create_new(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER], space.guid)
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(PackageCreate).to receive(:create).and_raise(PackageCreate::InvalidPackage.new('err'))
        end

        it 'returns 422' do
          expect {
            controller.create_new(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end
    end

    describe '#create_copy' do
      let(:target_app) { AppModel.make }
      let(:space) { target_app.space }
      let(:org) { space.organization }

      let(:source_app) { AppModel.make }
      let(:original_package) { PackageModel.make(type: 'bits', app_guid: source_app.guid) }

      let(:params) { { 'source_package_guid' => original_package.guid } }

      let(:package_response) { 'foobar' }

      before do
        allow(package_presenter).to receive(:present_json).and_return(package_response)
        allow(controller).to receive(:check_write_permissions!).and_return(nil)
        allow(membership).to receive(:has_any_roles?).and_return(true)
      end

      it 'returns a 201 and the response' do
        expect(target_app.packages.count).to eq(0)

        response_code, response = controller.create_copy(target_app.guid)

        expect(response_code).to eq 201
        expect(package_presenter).to have_received(:present_json).with(an_instance_of(PackageModel))
        expect(response).to eq(package_response)

        target_app.reload
        package = target_app.packages.first
        expect(package.type).to eq(original_package.type)
      end

      context 'when the user does not have write scope' do
        before do
          allow(controller).to receive(:check_write_permissions!).and_raise(
              VCAP::Errors::ApiError.new_from_details('NotAuthorized')
            )
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the source package does not exist' do
        let(:params) { { 'source_package_guid' => 'bogus-guid' } }

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the source package' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER],
              source_app.space.guid, source_app.space.organization.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot modify the source target_app' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER],
              source_app.space.guid, source_app.space.organization.guid).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], source_app.space.guid).and_return(false)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], source_app.space.guid)
        end
      end

      context 'when the target target_app does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.create_copy('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the target target_app' do
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
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot create the package' do
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

        it 'returns a 403 NotAuthorized error' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], space.guid)
        end
      end

      context 'when the source target_app and the target target_app are the same' do
        let(:original_package) { PackageModel.make(type: 'bits', app_guid: target_app.guid) }

        it 'returns 422' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(PackageCopy).to receive(:copy).and_raise(PackageCopy::InvalidPackage.new('err'))
        end

        it 'returns 422' do
          expect {
            controller.create_copy(target_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end
    end

    describe '#list_packages' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { space.organization }
      let(:guid) { app.guid }
      let(:list_response) { 'list_response' }

      before do
        allow(membership).to receive(:has_any_roles?).and_return(true)
        allow(package_presenter).to receive(:present_json_list).and_return(list_response)
        allow(controller).to receive(:check_read_permissions!).and_return(nil)
      end

      it 'returns a 200 and presents the response' do
        app.add_package(PackageModel.make)
        app.add_package(PackageModel.make)
        PackageModel.make
        PackageModel.make

        response_code, response = controller.list_packages(guid)
        expect(response_code).to eq 200

        expect(response).to eq(list_response)
        expect(package_presenter).to have_received(:present_json_list).
            with(an_instance_of(PaginatedResult), "/v3/apps/#{guid}/packages") do |result|
          expect(result.total).to eq(2)
        end
      end

      context 'when the user does not have read permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            controller.list_packages(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            controller.list_packages(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the app' do
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
            controller.list_packages(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the request parameters are invalid' do
        context 'because there are unknown parameters' do
          let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

          it 'returns an 400 Bad Request' do
            expect {
              controller.list_packages(guid)
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
              controller.list_packages(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include('Per page must be between 1 and 5000')
            end
          end
        end
      end
    end
  end
end
