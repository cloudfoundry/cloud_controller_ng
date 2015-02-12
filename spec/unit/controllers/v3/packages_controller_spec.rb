require 'spec_helper'

module VCAP::CloudController
  describe PackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:params) { {} }
    let(:packages_handler) { double(:packages_handler) }
    let(:apps_handler) { double(:apps_handler) }
    let(:droplets_handler) { double(:droplets_handler) }
    let(:package_presenter) { double(:package_presenter) }
    let(:droplet_presenter) { double(:droplet_presenter) }
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
          droplets_handler: droplets_handler,
          droplet_presenter: droplet_presenter,
          apps_handler: apps_handler
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

      context 'when the space does not exist' do
        before do
          allow(packages_handler).to receive(:upload).and_raise(PackagesHandler::SpaceNotFound)
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
      context 'when the package does not exist' do
        before do
          allow(packages_handler).to receive(:delete).and_return([])
        end

        it 'returns a 404 Not Found' do
          expect {
            packages_controller.delete('non-existant')
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
          before do
            allow(packages_handler).to receive(:delete).and_return([package])
          end

          it 'returns a 204 NO CONTENT' do
            response_code, response = packages_controller.delete(package.guid)
            expect(response_code).to eq 204
            expect(response).to be_nil
          end
        end

        context 'when the user cannot access the package' do
          before do
            allow(packages_handler).to receive(:delete).and_raise(PackagesHandler::Unauthorized)
          end

          it 'returns a 403 NotAuthorized error' do
            expect {
              packages_controller.delete(package_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
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
      let(:package) { PackageModel.make }
      let(:droplet_response) { 'barbaz' }

      before do
        allow(droplet_presenter).to receive(:present_json).and_return(droplet_response)
      end

      context 'when the buildpack does not exist' do
        before do
          allow(droplets_handler).to receive(:create).and_raise(DropletsHandler::BuildpackNotFound)
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

      context 'when the package does not exist' do
        before do
          allow(droplets_handler).to receive(:create).and_raise(DropletsHandler::PackageNotFound)
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

      context 'when the package exists' do
        context 'and the user is a space developer' do
          it 'returns a 201 Created response' do
            expect(droplets_handler).to receive(:create)

            response_code, body = packages_controller.stage(package.guid)
            expect(response_code).to eq 201
            expect(body).to eq droplet_response
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

      context 'when the space does not exist' do
        before do
          allow(droplets_handler).to receive(:create).and_raise(DropletsHandler::SpaceNotFound)
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

      context 'when the request is invalid' do
        before do
          allow(droplets_handler).to receive(:create).and_raise(DropletsHandler::InvalidRequest)
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
        before do
          allow(droplets_handler).to receive(:create).and_raise(DropletsHandler::Unauthorized)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            packages_controller.stage(package.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end
    end
  end
end
