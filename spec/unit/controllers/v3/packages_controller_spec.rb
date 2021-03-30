require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe PackagesController, type: :controller do
  describe '#upload' do
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:space) { package.space }
    let(:org) { space.organization }
    let(:params) { { 'bits_path' => 'path/to/bits' } }
    let(:form_headers) { { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' } }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      @request.env.merge!(form_headers)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      allow(File).to receive(:rename)
    end

    it 'returns 200 and updates the package state' do
      post :upload, params: params.merge(guid: package.guid)

      expect(response.status).to eq(200)
      expect(MultiJson.load(response.body)['guid']).to eq(package.guid)
      expect(package.reload.state).to eq(VCAP::CloudController::PackageModel::PENDING_STATE)
    end

    context 'when the bits service is enabled' do
      let(:bits_service_double) { double('bits_service') }
      let(:blob_double) { double('blob') }
      let(:bits_service_public_upload_url) { 'https://some.public/signed/url/to/upload/package' }

      before do
        VCAP::CloudController::Config.config.set(:bits_service, { enabled: true })

        allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
          and_return(bits_service_double)
        allow(bits_service_double).to receive(:blob).and_return(blob_double)
        allow(blob_double).to receive(:public_upload_url).and_return(bits_service_public_upload_url)
      end

      context 'when the user can write to the space' do
        it 'returns a bits service upload link' do
          post :upload, params: params.merge(guid: package.guid)

          expect(response.status).to eq(200)
          expect(MultiJson.load(response.body)['links']['upload']['href']).to match(bits_service_public_upload_url)
        end
      end
    end

    context 'when uploading with resources' do
      let(:params) do
        { 'bits_path' => 'path/to/bits', guid: package.guid }
      end

      context 'with unsupported options' do
        let(:new_options) do
          {
            cached_resources: JSON.dump([{ 'fn' => 'lol', 'sha1' => 'abc', 'size' => 2048 }]),
          }
        end

        it 'returns a 422 and the package' do
          post :upload, params: params.merge(new_options), as: :json

          expect(response.status).to eq(422), response.body
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include "Unknown field(s): 'cached_resources'"
        end
      end

      context 'with invalid json resources' do
        let(:new_options) do
          {
            resources: '[abcddf]',
          }
        end

        it 'returns a 422 and the package' do
          post :upload, params: params.merge(new_options), as: :json

          expect(response.status).to eq(422), response.body
          expect(response.body).to include 'UnprocessableEntity'
        end
      end

      context 'with correctly named cached resources' do
        shared_examples_for :uploading_successfully do
          let(:uploader) { instance_double(VCAP::CloudController::PackageUpload, upload_async: nil) }

          before do
            allow(VCAP::CloudController::PackageUpload).to receive(:new).and_return(uploader)
          end

          it 'returns a 201 and the package' do
            post :upload, params: params.merge(new_options), as: :json

            expect(response.status).to eq(200), response.body
            expect(MultiJson.load(response.body)['guid']).to eq(package.guid)
            expect(package.reload.state).to eq(VCAP::CloudController::PackageModel::CREATED_STATE)
            expect(uploader).to have_received(:upload_async) do |args|
              expect(args[:message].resources).to match_array([{ fn: 'lol', sha1: 'abc', size: 2048, mode: '645' }])
            end
          end
        end

        context 'v2 resource format' do
          let(:new_options) do
            {
              resources: JSON.dump([{ 'fn' => 'lol', 'sha1' => 'abc', 'size' => 2048, 'mode' => '645' }]),
            }
          end

          include_examples :uploading_successfully
        end

        context 'v3 resource format' do
          let(:new_options) do
            {
              resources: JSON.dump([{ 'path' => 'lol', 'checksum' => { 'value' => 'abc' }, 'size_in_bytes' => 2048, 'mode' => '645' }]),
            }
          end

          include_examples :uploading_successfully
        end
      end
    end

    context 'when app_bits_upload is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'app_bits_upload', enabled: false, error_message: nil)
      end

      context 'non-admin user' do
        it 'raises 403' do
          post :upload, params: params.merge(guid: package.guid), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('app_bits_upload')
        end
      end

      context 'admin user' do
        before { set_current_user_as_admin(user: user) }

        it 'returns 200 and updates the package state' do
          post :upload, params: params.merge(guid: package.guid), as: :json

          expect(response.status).to eq(200)
          expect(MultiJson.load(response.body)['guid']).to eq(package.guid)
          expect(package.reload.state).to eq(VCAP::CloudController::PackageModel::PENDING_STATE)
        end
      end
    end

    context 'when the package type is not bits' do
      before do
        package.type = 'docker'
        package.save
      end

      it 'returns a 422 Unprocessable' do
        post :upload, params: params.merge(guid: package.guid), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Package type must be bits.')
      end
    end

    context 'when the package does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :upload, params: params.merge(guid: 'not-real'), as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the message is not valid' do
      let(:params) { {} }

      it 'returns a 422 UnprocessableEntity error' do
        post :upload, params: params.merge(guid: package.guid), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the bits have already been uploaded' do
      before do
        package.state = VCAP::CloudController::PackageModel::READY_STATE
        package.save
      end

      it 'returns a 400 PackageBitsAlreadyUploaded error' do
        post :upload, params: params.merge(guid: package.guid), as: :json

        expect(response.status).to eq(400)
        expect(response.body).to include('PackageBitsAlreadyUploaded')
      end
    end

    context 'when the package is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::PackageUpload).to receive(:upload_async).and_raise(VCAP::CloudController::PackageUpload::InvalidPackage.new('err'))
      end

      it 'returns 422' do
        post :upload, params: params.merge(guid: package.guid), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'permissions' do
      context 'when the user does not have write scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.read'])
        end

        it 'returns an Unauthorized error' do
          post :upload, params: params.merge(guid: package.guid), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the package' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404' do
          post :upload, params: params.merge(guid: package.guid), as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not write to the space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 403' do
          post :upload, params: params.merge(guid: package.guid), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#download' do
    let(:package) { VCAP::CloudController::PackageModel.make(state: 'READY') }
    let(:space) { package.space }
    let(:org) { space.organization }
    let(:user) { set_current_user(VCAP::CloudController::User.make, email: 'utako') }

    before do
      blob = instance_double(CloudController::Blobstore::FogBlob, public_download_url: 'http://package.example.com')
      allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob)
      allow_any_instance_of(CloudController::Blobstore::Client).to receive(:local?).and_return(false)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns 302 and the redirect' do
      get :download, params: { guid: package.guid }

      expect(response.status).to eq(302)
      expect(response.headers['Location']).to eq('http://package.example.com')
    end

    context 'when the package is not of type bits' do
      before do
        package.type = 'docker'
        package.save
      end

      it 'returns 422' do
        get :download, params: { guid: package.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the package has no bits' do
      before do
        package.state = VCAP::CloudController::PackageModel::CREATED_STATE
        package.save
      end

      it 'returns 422' do
        get :download, params: { guid: package.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the package is stored in an image registry' do
      before do
        TestConfig.override({ packages: { image_registry: { base_path: 'hub.example.com/user' } } })
      end

      it 'returns 422' do
        get :download, params: { guid: package.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the package cannot be found' do
      it 'returns 404' do
        get :download, params: { guid: 'a-bogus-guid' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'user does not have read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
        end

        it 'returns an Unauthorized error' do
          get :download, params: { guid: package.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'user does not have package read permissions' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns 404' do
          get :download, params: { guid: package.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'user does not have package secrets permissions' do
        before do
          disallow_user_secret_access(user, space: space)
        end

        it 'returns 403' do
          get :download, params: { guid: package.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#show' do
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:space) { package.space }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      disallow_user_write_access(user, space: space)
    end

    it 'returns a 200 OK and the package' do
      get :show, params: { guid: package.guid }

      expect(response.status).to eq(200)
      expect(MultiJson.load(response.body)['guid']).to eq(package.guid)
    end

    context 'when the package does not exist' do
      it 'returns a 404 Not Found' do
        get :show, params: { guid: 'made-up-guid' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have the read scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.write'])
        end

        it 'returns a 403 NotAuthorized error' do
          get :show, params: { guid: package.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user can not read from the space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 not found' do
          get :show, params: { guid: package.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the bits service is enabled' do
        let(:bits_service_double) { double('bits_service') }
        let(:blob_double) { double('blob') }
        let(:bits_service_public_upload_url) { "https://some.public/signed/url/to/upload/package#{package.guid}" }

        before do
          VCAP::CloudController::Config.config.set(:bits_service, { enabled: true })

          allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
            and_return(bits_service_double)
          allow(bits_service_double).to receive(:blob).and_return(blob_double)
          allow(blob_double).to receive(:public_upload_url).and_return(bits_service_public_upload_url)
        end

        context 'when the user can write to the space' do
          before do
            allow_user_write_access(user, space: space)
          end

          it 'returns a bits service upload link' do
            get :show, params: { guid: package.guid }

            expect(response.status).to eq(200)
            expect(MultiJson.load(response.body)['links']['upload']['href']).to eq(bits_service_public_upload_url)
          end
        end

        context 'when the user can NOT write to the space' do
          before do
            disallow_user_write_access(user, space: space)
          end

          it 'does not return a bits service upload link' do
            get :show, params: { guid: package.guid }

            expect(response.status).to eq(200)
            expect(MultiJson.load(response.body)['links']['upload']).to be_nil
          end
        end
      end
    end
  end

  describe '#update' do
    let!(:org) { VCAP::CloudController::Organization.make(name: "Harold's Farm") }
    let!(:space) { VCAP::CloudController::Space.make(name: 'roosters', organization: org) }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'needed to put the package in the space', space: space) }
    let(:package) { VCAP::CloudController::PackageModel.make(app: app_model) }

    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:labels) do
      {
        fruit: 'pears',
        truck: 'hino'
      }
    end
    let(:annotations) do
      {
        potato: 'celandine',
        beet: 'formanova',
      }
    end
    let!(:update_message) do
      {
        metadata: {
          labels: {
            fruit: 'passionfruit'
          },
          annotations: {
            potato: 'adora'
          }
        }
      }
    end

    before do
      VCAP::CloudController::LabelsUpdate.update(package, labels, VCAP::CloudController::PackageLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(package, annotations, VCAP::CloudController::PackageAnnotationModel)
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      it 'updates the package' do
        patch :update, params: { guid: package.guid }.merge(update_message), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body['metadata']['labels']).to eq({ 'fruit' => 'passionfruit', 'truck' => 'hino' })
        expect(parsed_body['metadata']['annotations']).to eq({ 'potato' => 'adora', 'beet' => 'formanova' })

        package.reload
        expect(package).to have_labels(
          { key: 'fruit', value: 'passionfruit' },
          { key: 'truck', value: 'hino' }
        )
        expect(package).to have_annotations(
          { key: 'potato', value: 'adora' },
          { key: 'beet', value: 'formanova' }
        )
      end

      context 'when a label is deleted' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                fruit: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: package.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['labels']).to eq({ 'truck' => 'hino' })
          expect(package).to have_labels({ key: 'truck', value: 'hino' })
        end
      end
      context 'when an empty request is sent' do
        let(:request_body) do
          {}
        end

        it 'succeeds' do
          patch :update, params: { guid: package.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          package.reload
          expect(parsed_body['guid']).to eq(package.guid)
        end
      end

      context 'when the message is invalid' do
        before do
          set_current_user_as_admin
        end
        let!(:update_message2) { update_message.merge({ animals: 'Cows' }) }

        it 'fails' do
          patch :update, params: { guid: package.guid }.merge(update_message2), as: :json
          expect(response.status).to eq(422)
        end
      end

      context 'when there is no such package' do
        it 'fails' do
          patch :update, params: { guid: "Greg's missing package" }.merge(update_message), as: :json

          expect(response.status).to eq(404)
        end
      end

      context 'when there is an invalid label' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'cloudfoundry.org/label': 'value'
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: package.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/label [\w\s]+ error/)
        end
      end

      context 'when there is an invalid annotation' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                key: 'big' * 5000
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: package.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/is greater than 5000 characters/)
        end
      end

      context 'when there are too many annotations' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 2)
        end

        it 'fails with a 422' do
          patch :update, params: { guid: package.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/exceed maximum of 2/)
        end
      end

      context 'when an annotation is deleted' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                potato: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: package.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['annotations']).to eq({ 'beet' => 'formanova' })

          package.reload
          expect(package).to have_annotations({ key: 'beet', value: 'formanova' })
        end
      end
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 403,
            'global_auditor' => 403,
            'space_developer' => 200,
            'space_manager' => 403,
            'space_auditor' => 403,
            'org_manager' => 403,
            'org_auditor' => 404,
            'org_billing_manager' => 404,
          }
        end
        let(:api_call) { lambda { patch :update, params: { guid: package.guid }.merge(update_message), as: :json } }
      end

      context 'when the bits service is enabled' do
        let(:bits_service_double) { double('bits_service') }
        let(:blob_double) { double('blob') }
        let(:bits_service_public_upload_url) { "https://some.public/signed/url/to/upload/package#{package.guid}" }
        let(:user) { set_current_user(VCAP::CloudController::User.make) }

        before do
          VCAP::CloudController::Config.config.set(:bits_service, { enabled: true })

          allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
            and_return(bits_service_double)
          allow(bits_service_double).to receive(:blob).and_return(blob_double)
          allow(blob_double).to receive(:public_upload_url).and_return(bits_service_public_upload_url)
          allow_user_read_access_for(user, orgs: [org], spaces: [space])
        end

        context 'when the user can write to the space' do
          before do
            allow_user_write_access(user, space: space)
          end

          it 'returns a bits service upload link' do
            patch :update, params: { guid: package.guid }.merge(update_message), as: :json

            expect(response.status).to eq(200)
            expect(MultiJson.load(response.body)['links']['upload']['href']).to eq(bits_service_public_upload_url)
          end
        end
      end

      context 'permissions' do
        let(:user) { set_current_user(VCAP::CloudController::User.make) }

        context 'when the user cannot read the app' do
          before do
            disallow_user_read_access(user, space: space)
          end

          it 'returns a 404 ResourceNotFound error' do
            patch :update, params: { guid: app_model.guid }.merge(update_message), as: :json

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
          end
        end

        context 'when the user can read but cannot write to the app' do
          before do
            allow_user_read_access_for(user, spaces: [space])
            disallow_user_write_access(user, space: space)
          end

          it 'raises ApiError NotAuthorized' do
            patch :update, params: { guid: package.guid }.merge(update_message), as: :json

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
          end
        end
      end
    end
  end

  describe '#destroy' do
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { package.space }
    let(:package_delete_stub) { instance_double(VCAP::CloudController::PackageDelete) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      allow(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:new).and_call_original
      allow(VCAP::CloudController::PackageDelete).to receive(:new).and_return(package_delete_stub)
    end

    context 'when the package does not exist' do
      it 'returns a 404 Not Found' do
        delete :destroy, params: { guid: 'nono' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have write scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.read'])
        end

        it 'returns an Unauthorized error' do
          delete :destroy, params: { guid: package.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the package' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          delete :destroy, params: { guid: package.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but cannot write to the package' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          delete :destroy, params: { guid: package.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end

    it 'successfully deletes the package in a background job' do
      delete :destroy, params: { guid: package.guid }

      package_delete_jobs = Delayed::Job.where(Sequel.lit("handler like '%PackageDelete%'"))
      expect(package_delete_jobs.count).to eq 1
      package_delete_jobs.first

      expect(VCAP::CloudController::PackageModel.find(guid: package.guid)).not_to be_nil
      expect(VCAP::CloudController::Jobs::DeleteActionJob).to have_received(:new).with(
        VCAP::CloudController::PackageModel,
        package.guid,
        package_delete_stub,
      )
    end

    it 'creates a job to track the deletion and returns it in the location header' do
      expect {
        delete :destroy, params: { guid: package.guid }
      }.to change {
        VCAP::CloudController::PollableJobModel.count
      }.by(1)

      job = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('package.delete')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(package.guid)
      expect(job.resource_type).to eq('package')

      expect(response.status).to eq(202)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:space1) { VCAP::CloudController::Space.make }
    let(:space2) { VCAP::CloudController::Space.make }
    let(:space3) { VCAP::CloudController::Space.make }
    let(:user_spaces) { [space, space1, space2, space3] }
    let!(:user_package_1) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:user_package_2) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:admin_package) { VCAP::CloudController::PackageModel.make }

    before do
      allow_user_read_access_for(user, spaces: user_spaces)
    end

    it 'returns 200' do
      get :index
      expect(response.status).to eq(200)
    end

    it 'lists the packages visible to the user' do
      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([user_package_1, user_package_2].map(&:guid))
    end

    it 'returns pagination links for /v3/packages' do
      get :index
      expect(parsed_body['pagination']['first']['href']).to start_with("#{link_prefix}/v3/packages")
    end

    context 'when accessed as an app subresource' do
      it 'uses the app as a filter' do
        app = VCAP::CloudController::AppModel.make(space: space)
        package_1 = VCAP::CloudController::PackageModel.make(app_guid: app.guid)
        package_2 = VCAP::CloudController::PackageModel.make(app_guid: app.guid)
        VCAP::CloudController::PackageModel.make

        get :index, params: { app_guid: app.guid }

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([package_1.guid, package_2.guid])
      end

      it "doesn't allow filtering on space_guids in a nested query" do
        app = VCAP::CloudController::AppModel.make(space: space, guid: 'speshal-app-guid')

        get :index, params: { app_guid: app.guid, page: 1, per_page: 10, states: 'AWAITING_UPLOAD',
          space_guids: user_spaces.map(&:guid).join(',') }

        expect(response.status).to eq(400)
        expect(response.body).to include("Unknown query parameter(s): \'space_guids\'")
      end

      it 'uses the app and pagination as query parameters' do
        app = VCAP::CloudController::AppModel.make(space: space, guid: 'speshal-app-guid')
        package_1 = VCAP::CloudController::PackageModel.make(app_guid: app.guid, guid: 'package-1')
        package_2 = VCAP::CloudController::PackageModel.make(app_guid: app.guid, guid: 'package-2')
        VCAP::CloudController::PackageModel.make

        get :index, params: { app_guids: app.guid, page: 1, per_page: 10, states: 'AWAITING_UPLOAD', }

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([package_1.guid, package_2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, params: { app_guid: app_model.guid }
        expect(parsed_body['pagination']['first']['href']).to include("#{link_prefix}/v3/apps/#{app_model.guid}/packages")
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, params: { app_guid: 'hello-i-do-not-exist' }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, params: { app_guid: app_model.guid }

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      it 'lists all the packages' do
        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([user_package_1, user_package_2, admin_package].map(&:guid))
      end
    end

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params: params

        parsed_response = parsed_body
        response_guids = parsed_response['resources'].map { |r| r['guid'] }
        expect(parsed_response['pagination']['total_results']).to eq(2)
        expect(response_guids.length).to eq(per_page)
      end
    end

    context 'when parameters are invalid' do
      context 'because there are unknown parameters' do
        let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

        it 'returns an 400 Bad Request' do
          get :index, params: params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          m = /Unknown query parameter\(s\): '(\w+)', '(\w+)'/.match(response.body)
          expect(m).not_to be_nil
          expect([m[1], m[2]]).to match_array(%w/bad invalid/)
        end
      end

      context 'because there are invalid values in parameters' do
        let(:params) { { 'per_page' => 9999999999 } }

        it 'returns an 400 Bad Request' do
          get :index, params: params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Per page must be between')
        end
      end
    end

    context 'permissions' do
      context 'when the user can read but not write to the space' do
        it 'returns a 200 OK' do
          get :index
          expect(response.status).to eq(200)
        end
      end

      context 'when the user does not have the read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'returns a 403 NotAuthorized error' do
          get :index

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#create' do
    context 'when creating a new package' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      let(:app_guid) { app_model.guid }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:request_body) do
        {
          type: 'bits',
          relationships: { app: { data: { guid: app_guid } } }
        }
      end
      let(:user) { set_current_user(VCAP::CloudController::User.make) }

      before do
        allow_user_read_access_for(user, spaces: [space])
        allow_user_write_access(user, space: space)
      end

      context 'bits' do
        it 'returns a 201 and the package' do
          expect(app_model.packages.count).to eq(0)

          post :create, params: request_body, as: :json

          expect(response.status).to eq 201
          expect(app_model.reload.packages.count).to eq(1)
          created_package = app_model.packages.first

          response_guid = parsed_body['guid']
          expect(response_guid).to eq created_package.guid
        end

        context 'with an invalid type field' do
          let(:request_body) do
            {
              type: 'ninja',
              relationships: { app: { data: { guid: app_model.guid } } }
            }
          end

          it 'returns an UnprocessableEntity error' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include "must be one of 'bits, docker'"
          end
        end

        context 'when the app does not exist' do
          let(:app_guid) { 'bogus-guid' }

          it 'returns a 422 UnprocessableEntity error' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
          end
        end

        context 'when the package is invalid' do
          before do
            allow(VCAP::CloudController::PackageCreate).to receive(:create).and_raise(VCAP::CloudController::PackageCreate::InvalidPackage.new('err'))
          end

          it 'returns 422' do
            post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
          end
        end

        context 'when the bits service is enabled' do
          let(:bits_service_double) { double('bits_service') }
          let(:blob_double) { double('blob') }
          let(:bits_service_public_upload_url) { 'https://some.public/signed/url/to/upload/package' }

          before do
            VCAP::CloudController::Config.config.set(:bits_service, { enabled: true })

            allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
              and_return(bits_service_double)
            allow(bits_service_double).to receive(:blob).and_return(blob_double)
            allow(blob_double).to receive(:public_upload_url).and_return(bits_service_public_upload_url)
          end

          context 'when the user can write to the space' do
            it 'returns a bits service upload link' do
              post :create, params: request_body, as: :json

              expect(response.status).to eq(201)
              expect(MultiJson.load(response.body)['links']['upload']['href']).to match(bits_service_public_upload_url)
            end
          end
        end

        context 'when the existing app is a Docker app' do
          let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }

          it 'returns 422' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response).to have_error_message('Cannot create bits package for a Docker app.')
          end
        end

        context 'permissions' do
          context 'when the user does not have write scope' do
            before do
              set_current_user(user, scopes: ['cloud_controller.read'])
            end

            it 'returns a 403 NotAuthorized error' do
              post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

              expect(response.status).to eq 403
              expect(response.body).to include 'NotAuthorized'
            end
          end

          context 'when the user cannot read the app' do
            before do
              disallow_user_read_access(user, space: space)
            end

            it 'returns a 422 UnprocessableEntity error' do
              post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

              expect(response.status).to eq 422
              expect(response.body).to include 'UnprocessableEntity'
            end
          end

          context 'when the user can read but not write to the space' do
            before do
              disallow_user_write_access(user, space: space)
            end

            it 'returns a 422 UnprocessableEntity error' do
              post :create, params: { app_guid: app_model.guid }.merge(request_body), as: :json

              expect(response.status).to eq 422
              expect(response.body).to include 'UnprocessableEntity'
            end
          end
        end
      end

      context 'docker' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }
        let(:image) { 'registry/image:latest' }
        let(:docker_username) { 'naruto' }
        let(:docker_password) { 'oturan' }
        let(:request_body) do
          {
            relationships: { app: { data: { guid: app_model.guid } } },
            type: 'docker',
            data: {
              image: image,
              username: docker_username,
              password: docker_password
            }
          }
        end

        it 'returns a 201' do
          expect(app_model.packages.count).to eq(0)
          post :create, params: request_body, as: :json

          expect(response.status).to eq 201

          app_model.reload
          package = app_model.packages.first
          expect(package.type).to eq('docker')
          expect(package.image).to eq('registry/image:latest')
          expect(package.docker_username).to eq(docker_username)
          expect(package.docker_password).to eq(docker_password)
        end

        context 'when the existing app is a buildpack app' do
          let(:app_model) { VCAP::CloudController::AppModel.make }

          it 'returns 422' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response).to have_error_message('Cannot create Docker package for a buildpack app.')
          end
        end
      end

      context 'with metadata' do
        let(:metadata_request_body) { request_body.merge(metadata) }
        context 'when the label is invalid' do
          let(:metadata) do
            {
              metadata: {
                labels: {
                  'cloudfoundry.org/release' => 'stable'
                }
              }
            }
          end

          it 'returns an UnprocessableEntity error' do
            post :create, params: metadata_request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response).to have_error_message(/label [\w\s]+ error/)
          end
        end

        context 'when the annotation is invalid' do
          let(:metadata) do
            {
              metadata: {
                annotations: {
                  '' => 'stable'
                }
              }
            }
          end

          it 'returns an UnprocessableEntity error' do
            post :create, params: metadata_request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response).to have_error_message(/annotation [\w\s]+ error/)
          end
        end

        context 'when the metadata is valid' do
          let(:metadata) do
            {
              metadata: {
                labels: {
                  'release' => 'stable'
                },
                annotations: {
                  'notes' => 'detailed information'
                }
              }
            }
          end

          it 'Returns a 201 and the app with metadata' do
            post :create, params: metadata_request_body, as: :json

            response_body = parsed_body
            response_metadata = response_body['metadata']

            expect(response.status).to eq(201)
            expect(response_metadata['labels']['release']).to eq 'stable'
            expect(response_metadata['annotations']['notes']).to eq 'detailed information'
          end
        end
      end
    end

    context 'when copying an existing package' do
      let(:source_app_model) { VCAP::CloudController::AppModel.make }
      let(:original_package) { VCAP::CloudController::PackageModel.make(type: 'bits', app_guid: source_app_model.guid) }
      let(:target_app_model) { VCAP::CloudController::AppModel.make }
      let(:user) { set_current_user(VCAP::CloudController::User.make) }
      let(:source_space) { source_app_model.space }
      let(:destination_space) { target_app_model.space }
      let(:relationship_request_body) { { relationships: { app: { data: { guid: target_app_model.guid } } } } }

      before do
        allow_user_read_access_for(user, spaces: [source_space, destination_space])
        allow_user_write_access(user, space: source_space)
        allow_user_write_access(user, space: destination_space)
      end

      context 'when the package is stored in an image registry' do
        before do
          TestConfig.override({ packages: { image_registry: { base_path: 'hub.example.com/user' } } })
        end

        it 'returns 422' do
          post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

          expect(response.status).to eq 422
          expect(response.body).to include('UnprocessableEntity')
        end
      end

      it 'returns a 201 and the response' do
        expect(target_app_model.packages.count).to eq(0)

        post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

        copied_package = target_app_model.reload.packages.first
        response_guid = parsed_body['guid']

        expect(response.status).to eq 201
        expect(copied_package.type).to eq(original_package.type)
        expect(response_guid).to eq copied_package.guid
      end

      context 'when the bits service is enabled' do
        let(:bits_service_double) { double('bits_service') }
        let(:blob_double) { double('blob') }
        let(:bits_service_public_upload_url) { 'https://some.public/signed/url/to/upload/package' }

        before do
          VCAP::CloudController::Config.config.set(:bits_service, { enabled: true })

          allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
            and_return(bits_service_double)
          allow(bits_service_double).to receive(:blob).and_return(blob_double)
          allow(blob_double).to receive(:public_upload_url).and_return(bits_service_public_upload_url)
        end

        context 'when the user can write to the space' do
          it 'returns a bits service upload link' do
            post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

            expect(response.status).to eq(201)
            expect(MultiJson.load(response.body)['links']['upload']['href']).to match(bits_service_public_upload_url)
          end
        end
      end

      context 'permissions' do
        context 'when the user does not have write scope' do
          before do
            set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
          end

          it 'returns a 403 NotAuthorized error' do
            post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
          end
        end

        context 'when the user cannot read the source package' do
          before do
            disallow_user_read_access(user, space: source_space)
          end

          it 'returns a 422 UnprocessableEntity error' do
            post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
          end
        end

        context 'when the user cannot modify the source target_app' do
          before do
            allow_user_read_access_for(user, spaces: [source_space, destination_space])
            disallow_user_write_access(user, space: source_space)
          end

          it 'returns a 403 Unauthorized error' do
            post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
          end
        end

        context 'when the user cannot read the target app' do
          before do
            disallow_user_read_access(user, space: destination_space)
          end

          it 'returns a 422 UnprocessableEntity error' do
            post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
          end
        end

        context 'when the user cannot create the package' do
          before do
            allow_user_read_access_for(user, spaces: [destination_space])
            disallow_user_write_access(user, space: destination_space)
          end

          it 'returns a 403 Unauthorized error' do
            post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
          end
        end
      end

      context 'when the source package does not exist' do
        it 'returns a 422 UnprocessableEntity error' do
          post :create, params: { source_guid: 'bogus package guid' }.merge(relationship_request_body), as: :json

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
        end
      end

      context 'when the target target_app does not exist' do
        let(:relationship_request_body) { { relationships: { app: { data: { guid: 'bogus' } } } } }

        it 'returns a 422 UnprocessableEntity error' do
          post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(VCAP::CloudController::PackageCopy).to receive(:copy).and_raise(VCAP::CloudController::PackageCopy::InvalidPackage.new('ruh roh'))
        end

        it 'returns 422' do
          post :create, params: { source_guid: original_package.guid }.merge(relationship_request_body), as: :json

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include 'ruh roh'
        end
      end
    end
  end
end
