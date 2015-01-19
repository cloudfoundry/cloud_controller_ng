require 'spec_helper'

module VCAP::CloudController
  describe PackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:params) { {} }
    let(:packages_handler) { double(:packages_handler) }
    let(:apps_handler) { double(:apps_handler) }
    let(:package_presenter) { double(:package_presenter) }
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
          apps_handler: apps_handler
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
    end

    describe '#create' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:app_model) { AppModel.make }
      let(:app_guid) { app_model.guid }
      let(:space_guid) { app_model.space_guid }
      let(:package) { PackageModel.make }
      let(:req_body) { '{"type":"bits"}' }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, 'file.zip')
        TestZip.create(zip_name, 1, 1024)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:package_response) { 'foobar' }

      before do
        allow(package_presenter).to receive(:present_json).and_return(MultiJson.dump(package_response, pretty: true))
        allow(packages_handler).to receive(:create).and_return(package)
        allow(apps_handler).to receive(:show).and_return(app_model)
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      context 'when the app exists' do
        context 'when a user can create a package' do
          it 'returns a 201 Created response' do
            response_code, _ = packages_controller.create(app_guid)
            expect(response_code).to eq 201
          end

          it 'returns the package' do
            _, response = packages_controller.create(app_guid)
            expect(MultiJson.load(response, symbolize_keys: true)).to eq(package_response)
          end
        end

        context 'as a developer' do
          let(:user) { make_developer_for_space(app_model.space) }

          context 'with an invalid package' do
            let(:req_body) { 'all sorts of invalid' }

            it 'returns an UnprocessableEntity error' do
              expect {
                packages_controller.create(app_guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end

          context 'with an invalid type field' do
            let(:req_body) { '{ "type": "ninja" }' }

            it 'returns an UnprocessableEntity error' do
              expect {
                packages_controller.create(app_guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end

        context 'when the user cannot create a package' do
          before do
            allow(packages_handler).to receive(:create).and_raise(PackagesHandler::Unauthorized)
          end

          it 'returns a 403 NotAuthorized error' do
            expect {
              packages_controller.create(app_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end
      end

      context 'when the app does not exist' do
        before do
          allow(apps_handler).to receive(:show).and_return(nil)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            packages_controller.create('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
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
          allow(packages_handler).to receive(:delete).and_return(nil)
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
            allow(packages_handler).to receive(:delete).and_return(package)
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
  end
end
