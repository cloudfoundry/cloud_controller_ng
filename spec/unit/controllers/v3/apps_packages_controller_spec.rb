require 'spec_helper'

module VCAP::CloudController
  describe AppsPackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:package_handler) { double(:package_handler) }
    let(:package_presenter) { double(:package_presenter) }
    let(:apps_handler) { double(:apps_handler) }
    let(:app_model) { nil }
    let(:controller) do
      AppsPackagesController.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          apps_handler:      apps_handler,
          packages_handler:  package_handler,
          package_presenter: package_presenter
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(apps_handler).to receive(:show).and_return(app_model)
    end

    describe '#create' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:app_model) { AppModel.make }
      let(:app_guid) { app_model.guid }
      let(:space_guid) { app_model.space_guid }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }
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
        allow(package_handler).to receive(:create).and_return(package)
        allow(apps_handler).to receive(:show).and_return(app_model)
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      context 'when the app exists' do
        context 'when a user can create a package' do
          it 'returns a 201 Created response' do
            response_code, _ = controller.create(app_guid)
            expect(response_code).to eq 201
          end

          it 'returns the package' do
            _, response = controller.create(app_guid)
            expect(package_presenter).to have_received(:present_json).with(package)
            expect(MultiJson.load(response, symbolize_keys: true)).to eq(package_response)
          end
        end

        context 'as a developer' do
          let(:user) { make_developer_for_space(app_model.space) }

          context 'with an invalid package' do
            let(:req_body) { 'all sorts of invalid' }

            it 'returns an UnprocessableEntity error' do
              expect {
                controller.create(app_guid)
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
                controller.create(app_guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end

        context 'when the user cannot create a package' do
          before do
            allow(package_handler).to receive(:create).and_raise(PackagesHandler::Unauthorized)
          end

          it 'returns a 403 NotAuthorized error' do
            expect {
              controller.create(app_guid)
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
            controller.create('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe '#list_packages' do
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

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }
        let(:list_response) { 'list_response' }
        let(:package_response) { 'package_response' }

        before do
          allow(package_presenter).to receive(:present_json_list).and_return(package_response)
          allow(package_handler).to receive(:list).and_return(list_response)
        end

        it 'returns a 200' do
          response_code, _ = controller.list_packages(guid)
          expect(response_code).to eq 200
        end

        it 'returns the packages' do
          _, response = controller.list_packages(guid)
          expect(response).to eq(package_response)
        end
      end
    end
  end
end
