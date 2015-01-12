require 'spec_helper'
require 'handlers/packages_handler'

module VCAP::CloudController
  describe PackageUploadMessage do
    let(:guid) { 'my-guid' }

    context 'when the path is not provided' do
      let(:opts) { {} }
      it 'is not valid' do
        create_message = PackageUploadMessage.new(guid, opts)
        valid, error = create_message.validate
        expect(valid).to be_falsey
        expect(error).to include('An application zip file must be uploaded.')
      end
    end

    context 'and the path is provided' do
      let(:opts) { { 'bits_path' => 'foobar' } }
      it 'is valid' do
        create_message = PackageUploadMessage.new(guid, opts)
        valid, error = create_message.validate
        expect(valid).to be_truthy
        expect(error).to be_nil
      end
    end
  end

  describe PackageCreateMessage do
    let(:guid) { 'my-guid' }

    context 'when a type parameter that is not allowed is provided' do
      let(:opts) { { 'type' => 'not-allowed'  } }

      it 'is not valid' do
        create_message = PackageCreateMessage.new(guid, opts)
        valid, errors = create_message.validate
        expect(valid).to be_falsey
        expect(errors).to include('The type field needs to be one of \'bits, docker\'')
      end
    end

    context 'when nil type is provided' do
      let(:opts) { { 'type' => nil } }

      it 'is not valid' do
        create_message = PackageCreateMessage.new(guid, opts)
        valid, errors = create_message.validate
        expect(valid).to be_falsey
        expect(errors).to include('The type field is required')
      end
    end

    context 'when type is bits' do
      let(:opts) { { 'type' => 'bits' } }

      context 'no url is provided' do
        it 'is valid' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_truthy
          expect(errors).to be_empty
        end
      end

      context 'and a url is provided' do
        let(:opts) { { 'type' => 'bits', 'url' => 'foobar' } }

        it 'is not valid' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_falsey
          expect(errors).to include('The url field cannot be provided when type is bits.')
        end
      end
    end

    context 'when type is docker' do
      context 'and a url is provided' do
        let(:opts) { { 'type' => 'docker', 'url' => 'foobar' } }
        it 'is valid' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_truthy
          expect(errors).to be_empty
        end
      end

      context 'and a url is not provided' do
        let(:opts) { { 'type' => 'docker' } }

        it 'is not valid' do
          create_message = PackageCreateMessage.new(guid, opts)
          valid, errors = create_message.validate
          expect(valid).to be_falsey
          expect(errors).to include('The url field must be provided for type docker.')
        end
      end
    end

    describe 'create_from_http_request' do
      context 'when the body is valid json' do
        let(:body) { MultiJson.dump({ type: 'bits' }) }

        it 'creates a PackageCreateMessage from the json' do
          pcm           = PackageCreateMessage.create_from_http_request(guid, body)
          valid, errors = pcm.validate

          expect(valid).to be_truthy
          expect(errors).to be_empty
        end
      end

      context 'when the body is not valid json' do
        let(:body) { '{{' }

        it 'returns a PackageCreateMessage that is not valid' do
          pcm           = PackageCreateMessage.create_from_http_request(guid, body)
          valid, errors = pcm.validate

          expect(valid).to be_falsey
          expect(errors[0]).to include('parse error')
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
    let(:space) { Space.make }

    before do
      allow(access_context).to receive(:cannot?).and_return(false)
    end

    describe '#create' do
      let(:url) { 'docker://cloudfoundry/runtime-ci' }
      let(:create_opts) do
        {
          'type' => 'docker',
          'url' => url
        }
      end

      context 'when the space exists' do
        let(:create_message) { PackageCreateMessage.new(space.guid, create_opts) }

        context 'when a user can create a package' do
          it 'creates the package' do
            result = packages_handler.create(create_message, access_context)

            created_package = PackageModel.find(guid: result.guid)
            expect(created_package).to eq(result)
          end

          context 'when the type is bits' do
            let(:create_opts) { { 'type' => 'bits' } }

            it 'adds a delayed job to upload the package bits' do
              result = packages_handler.create(create_message, access_context)

              expect(result.type).to eq('bits')
              expect(result.state).to eq(PackageModel::CREATED_STATE)
              expect(result.url).to be_nil
            end
          end

          context 'when the type is docker' do
            it 'adds a delayed job to upload the package bits' do
              result = packages_handler.create(create_message, access_context)

              expect(result.type).to eq('docker')
              expect(result.state).to eq('READY')
              expect(result.url).to eq(url)
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
            expect(access_context).to have_received(:cannot?).with(:create, kind_of(PackageModel), space)
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

      context 'when the space does not exist' do
        let(:create_message) { PackageCreateMessage.new('non-existant', create_opts) }

        it 'raises SpaceNotFound' do
          expect {
            packages_handler.create(create_message, access_context)
          }.to raise_error(PackagesHandler::SpaceNotFound)
        end
      end
    end

    describe '#upload' do
      let(:package) { PackageModel.make(space_guid: space_guid, type: 'bits', state: PackageModel::CREATED_STATE) }
      let(:upload_message) { PackageUploadMessage.new(package_guid, upload_opts) }
      let(:create_opts) { { 'bit_path' => 'path/to/bits' } }
      let(:upload_opts) { { 'bits_path' => 'foobar' } }
      let(:package_guid) { package.guid }
      let(:space_guid) { space.guid }

      before do
        allow(access_context).to receive(:cannot?).and_return(false)
      end

      context 'when the package exists' do
        context 'when the space exists' do
          context 'when the user can access the package' do
            context 'when the package is of type bits' do
              before do
                config[:name] = 'local'
                config[:index] = '1'
              end

              it 'enqueues a upload job' do
                expect {
                  packages_handler.upload(upload_message, access_context)
                }.to change { Delayed::Job.count }.by(1)

                job = Delayed::Job.last
                expect(job.queue).to eq('cc-local-1')
                expect(job.handler).to include(package_guid)
                expect(job.handler).to include('PackageBits')
              end

              it 'changes the state to pending' do
                packages_handler.upload(upload_message, access_context)
                expect(PackageModel.find(guid: package_guid).state).to eq(PackageModel::PENDING_STATE)
              end

              it 'returns the package' do
                resulting_package = packages_handler.upload(upload_message, access_context)
                expected_package = PackageModel.find(guid: package_guid)
                expect(resulting_package.guid).to eq(expected_package.guid)
              end

              context 'when the bits have already been uploaded' do
                before do
                  package.state =  PackageModel::PENDING_STATE
                  package.save
                end

                it 'raises BitsAlreadyUploaded error' do
                  expect {
                    packages_handler.upload(upload_message, access_context)
                  }.to raise_error(PackagesHandler::BitsAlreadyUploaded)
                end
              end
            end

            context 'when the package is not of type bits' do
              let(:package) { PackageModel.make(space_guid: space_guid, type: 'docker') }

              it 'raises an InvalidPackage exception' do
                expect {
                  packages_handler.upload(upload_message, access_context)
                }.to raise_error(PackagesHandler::InvalidPackageType)
              end
            end
          end

          context 'when the user cannot access the package' do
            before do
              allow(access_context).to receive(:cannot?).and_return(true)
            end

            it 'raises an Unathorized exception' do
              expect {
                packages_handler.upload(upload_message, access_context)
              }.to raise_error(PackagesHandler::Unauthorized)
            end
          end
        end

        context 'when the space does not exist' do
          let(:space_guid) { 'non-existant' }

          it 'raises an SpaceNotFound exception' do
            expect {
              packages_handler.upload(upload_message, access_context)
            }.to raise_error(PackagesHandler::SpaceNotFound)
          end
        end
      end

      context 'when the package does not exist' do
        let(:package_guid) { 'non-existant' }

        it 'raises a PackageNotFound exception' do
          expect {
            packages_handler.upload(upload_message, access_context)
          }.to raise_error(PackagesHandler::PackageNotFound)
        end
      end
    end

    describe '#show' do
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

    describe '#delete' do
      let!(:package) { PackageModel.make(space_guid: space.guid) }
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
          expect(access_context).to have_received(:cannot?).with(:delete, kind_of(PackageModel), space)
        end
      end
    end
  end
end
