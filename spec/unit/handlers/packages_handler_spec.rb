require 'spec_helper'
require 'handlers/packages_handler'

module VCAP::CloudController
  describe PackageCreateMessage do
    context 'when a type parameter that is not allowed is provided' do
      let(:opts) { { 'type' => 'not-allowed'  } }
      let(:guid) { 'my-guid' }

      it 'is not valid' do
        create_message = PackageCreateMessage.new(guid, opts)
        valid, errors = create_message.validate
        expect(valid).to be_falsey
        expect(errors).to include('The type field needs to be one of \'bits, docker\'')
      end
    end

    context 'when nil type is provided' do
      let(:opts) { { 'type' => nil } }
      let(:guid) { 'my-guid' }

      it 'is not valid' do
        create_message = PackageCreateMessage.new(guid, opts)
        valid, errors = create_message.validate
        expect(valid).to be_falsey
        expect(errors).to include('The type field is required')
      end
    end

    context 'when type is bits' do
      let(:opts) { { 'type' => 'bits', 'bits_path' => nil, 'bits_name' => nil } }
      let(:guid) { 'my-guid' }

      context 'and no zip file is uploaded' do
        it 'is not valid' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_falsey
          expect(errors).to include('Must upload an application zip file')
        end
      end

      context 'and a zip file is uploaded' do
        let(:opts) { { 'type' => 'bits', 'bits_path' => '/tmp', 'bits_name' => 'app.zip' } }

        it 'is valid' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_truthy
          expect(errors).to be_empty
        end
      end

      context 'when type is docker' do
        let(:opts) { { 'type' => 'docker', 'bits_path' => nil, 'bits_name' => nil } }
        it 'does not care about a zip file' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_truthy
          expect(errors).to be_empty
        end
      end
    end
  end

  describe PackagesHandler do
    let(:tmpdir) { Dir.mktmpdir }
    let(:valid_zip) {
      zip_name = File.join(tmpdir, 'file.zip')
      TestZip.create(zip_name, 1, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    }

    let(:config) { TestConfig.config }
    let(:packages_handler) { described_class.new(config) }
    let(:access_context) { double(:access_context) }
    let(:app) { AppModel.make(space_guid: space.guid) }
    let(:space) { Space.make }

    before do
      allow(access_context).to receive(:cannot?).and_return(false)
    end

    describe '#create' do
      let(:create_opts) do
        {
          'type' => 'bits',
          'bits_path' =>  tmpdir,
          'bits_name' => 'file.zip',
        }
      end

      context 'when the app exists' do
        let(:create_message) { PackageCreateMessage.new(app.guid, create_opts) }

        context 'when a user can create a package' do
          it 'creates the package' do
            result = packages_handler.create(create_message, access_context)

            created_package = PackageModel.find(guid: result.guid)
            expect(created_package.app_guid).to eq(result.app_guid)
            expect(created_package.type).to eq(result.type)
          end

          context 'when the type is bits' do
            it 'adds a delayed job to upload the package bits' do
              result = nil
              expect {
                result = packages_handler.create(create_message, access_context)
              }.to change { Delayed::Job.count }.by(1)

              expect(result.state).to eq('PENDING')
            end
          end

          context 'when the type is docker' do
            let(:create_opts) { { 'type' => 'docker' } }

            it 'adds a delayed job to upload the package bits' do
              result = nil
              expect {
                result = packages_handler.create(create_message, access_context)
              }.to_not change { Delayed::Job.count }

              expect(result.state).to eq('READY')
            end
          end
        end

        context 'when the user cannot create an package' do
          before do
            allow(access_context).to receive(:cannot?).and_return(true)
          end

          it 'raises Unauthorized error' do
            expect {
              packages_handler.create(create_message, access_context)
            }.to raise_error(PackagesHandler::Unauthorized)
            expect(access_context).to have_received(:cannot?).with(:create, kind_of(PackageModel), app, space)
          end
        end

        context 'when the package is invalid' do
          before do
            allow_any_instance_of(PackageModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
          end

          it 'raises an PackageInvalid error' do
            expect {
              packages_handler.create(create_message, access_context)
            }.to raise_error(PackagesHandler::InvalidPackage, 'the message')
          end
        end
      end

      context 'when the app does not exist' do
        let(:create_message) { PackageCreateMessage.new('non-existant', create_opts) }

        it 'raises AppNotFound' do
          expect {
            packages_handler.create(create_message, access_context)
          }.to raise_error(PackagesHandler::AppNotFound)
        end
      end
    end

    describe 'show' do
      let(:package) { PackageModel.make }
      let(:package_guid) { package.guid }

      context 'when the package does not exist' do
        it 'returns nil' do
          expect(access_context).not_to receive(:cannot?)
          expect(packages_handler.show('non-existant', access_context)).to eq(nil)
        end
      end

      context 'when the package does exist' do
        context 'when the user can access a package' do
          before do
            allow(access_context).to receive(:cannot?).and_return(false)
          end

          it 'returns the package' do
            expect(packages_handler.show(package_guid, access_context)).to eq(package)
          end
        end

        context 'when the user cannot access a package' do
          before do
            allow(access_context).to receive(:cannot?).and_return(true)
          end

          it 'raises Unauthorized error' do
            expect {
              packages_handler.show(package_guid, access_context)
            }.to raise_error(PackagesHandler::Unauthorized)
            expect(access_context).to have_received(:cannot?).with(:read, kind_of(PackageModel))
          end
        end
      end
    end

    describe 'delete' do
      let!(:package) { PackageModel.make(app_guid: app.guid) }
      let(:package_guid) { package.guid }

      context 'when the user can access a package' do
        before do
          allow(access_context).to receive(:cannot?).and_return(false)
        end

        context 'and the package does not exist' do
          it 'returns nil' do
            expect(packages_handler.delete('non-existant', access_context)).to eq(nil)
          end
        end

        context 'and the package exists' do
          it 'deletes the package and returns the deleted package' do
            expect {
              deleted_package = packages_handler.delete(package_guid, access_context)
              expect(deleted_package.guid).to eq(package_guid)
            }.to change { PackageModel.count }.by(-1)
            expect(PackageModel.find(guid: package_guid)).to be_nil
          end

          it 'enqueues a job to delete the corresponding blob from the blobstore' do
            job_opts = { queue: 'cc-generic' }
            expect(Jobs::Enqueuer).to receive(:new).with(kind_of(BlobstoreDelete), job_opts).
              and_call_original

            expect {
              packages_handler.delete(package_guid, access_context)
            }.to change { Delayed::Job.count }.by(1)
          end
        end
      end

      context 'when the user cannot access a package' do
        before do
          allow(access_context).to receive(:cannot?).and_return(true)
        end

        it 'raises Unauthorized error' do
          expect {
            deleted_package = packages_handler.delete(package_guid, access_context)
            expect(deleted_package).to be_nil
          }.to raise_error(PackagesHandler::Unauthorized)
          expect(access_context).to have_received(:cannot?).with(:delete, kind_of(PackageModel), app, space)
        end
      end
    end
  end
end
