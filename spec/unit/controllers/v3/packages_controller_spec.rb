require 'spec_helper'

module VCAP::CloudController
  describe PackagesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:params) { {} }
    let(:packages_handler) { double(:process_handler) }
    let(:package_presenter) { double(:package_presenter) }

    let(:packages_controller) do
      PackagesController.new(
        {},
        logger,
        {},
        params.stringify_keys,
        '',
        nil,
        {
          packages_handler: packages_handler,
          package_presenter: package_presenter,
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
    end

    describe '#create' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:params) { { type: 'bits', bits_path: '/tmp/app.zip', bits_name: 'app.zip' } }
      let(:app_obj) { AppModel.make }
      let(:app_guid) { app_obj.guid }
      let(:package) { PackageModel.make }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, "file.zip")
        TestZip.create(zip_name, 1, 1024)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:package_response) do
        {
          type: "bits",
          package_hash: "a-hash",
          created_at: "a-date",
          _links: {
            app: {
              href: "/v3/apps/#{app_guid}",
            },
          },
        }
      end

      before do
        allow(package_presenter).to receive(:present_json).and_return(MultiJson.dump(package_response, pretty: true))
        allow(packages_handler).to receive(:create).and_return(package)
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

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

      context "as an admin" do
        let(:headers) { admin_headers }

        it "allows upload even if app_bits_upload flag is disabled" do
          FeatureFlag.make(name: 'app_bits_upload', enabled: false)
          response_code, _ = packages_controller.create(app_guid)
          expect(response_code).to eq 201
        end
      end

      context "as a developer" do
        let(:user) { make_developer_for_space(app_obj.space) }

        context "with an invalid package" do
          let(:params) { {} }

          it 'returns an UnprocessableEntity error' do
            expect {
              packages_controller.create(app_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq 422
            end
          end
        end

        context "with an invalid type field" do
          let(:params) { { type: 'ninja' } }

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
          let(:expected_response) { "im a response" }

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
