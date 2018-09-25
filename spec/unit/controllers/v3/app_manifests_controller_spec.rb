require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe AppManifestsController, type: :controller do
  describe '#apply_manifest' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let(:app_apply_manifest_action) { instance_double(VCAP::CloudController::AppApplyManifest) }
    let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 2 }] } }

    before do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)
      allow(VCAP::CloudController::Jobs::ApplyManifestActionJob).to receive(:new).and_call_original
      allow(VCAP::CloudController::AppApplyManifest).to receive(:new).and_return(app_apply_manifest_action)
      request.headers['CONTENT_TYPE'] = 'application/x-yaml'
    end

    context 'permissions' do
      describe 'authorization' do
        role_to_expected_http_response = {
          'admin' => 202,
          'admin_read_only' => 403,
          'global_auditor' => 403,
          'space_developer' => 202,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'org_auditor' => 404,
          'org_billing_manager' => 404,
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: org, space: space, user: user)

              post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            end
          end
        end
      end
    end

    context 'when the request body is invalid' do
      context 'when the yaml is missing an applications array' do
        let(:request_body) { { 'name' => 'blah', 'instances' => 4 } }

        it 'returns a 400' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml
          expect(response.status).to eq(400)
        end
      end

      context 'when the requested applications array is empty' do
        let(:request_body) { { 'applications' => [] } }

        it 'returns a 400' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml
          expect(response.status).to eq(400)
        end

        context 'when the app does not exist' do
          let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 1, 'memory' => '4MB' }] } }

          it 'returns a 400' do
            post :apply_manifest, params: { guid: 'no-such-app-guid' }.merge(request_body), as: :yaml
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when specified manifest fails validations' do
        let(:request_body) do
          { 'applications' => [{ 'name' => 'blah', 'instances' => -1, 'memory' => '10NOTaUnit',
                                 'command' => '', 'env' => 42,
                                 'health-check-http-endpoint' => '/endpoint',
                                 'health-check-invocation-timeout' => -22,
                                 'health-check-type' => 'foo',
                                 'timeout' => -42,
                                 'random-route' => -42,
                                 'routes' => [{ 'route' => 'garbage' }],
          }] }
        end

        it 'returns a 422 and validation errors' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml
          expect(response.status).to eq(422)
          errors = parsed_body['errors']
          expect(errors.size).to eq(10)
          expect(errors.map { |h| h.reject { |k, _| k == 'test_mode_info' } }).to match_array([
            {
              'detail' => 'Process "web": Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Process "web": Instances must be greater than or equal to 0',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Process "web": Command must be between 1 and 4096 characters',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Env must be a hash of keys and values',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Process "web": Health check type must be "http" to set a health check HTTP endpoint',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Process "web": Health check type must be "port", "process", or "http"',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Process "web": Health check invocation timeout must be greater than or equal to 1',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => 'Process "web": Timeout must be greater than or equal to 1',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
              'detail' => "The route 'garbage' is not a properly formed URL",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }, {
            'detail' => 'Random-route must be a boolean',
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008
          }
          ])
        end
      end

      context 'when the request payload is not yaml' do
        let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 1 }] } }
        before do
          allow(CloudController::Errors::ApiError).to receive(:new_from_details).and_call_original
          request.headers['CONTENT_TYPE'] = 'text/plain'
        end

        it 'returns a 400' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body)
          expect(response.status).to eq(400)
          # Verify we're getting the InvalidError we're expecting
          expect(CloudController::Errors::ApiError).to have_received(:new_from_details).with('InvalidRequest', 'Content-Type must be yaml').exactly :once
        end
      end
    end

    context 'when the request body includes a buildpack' do
      let!(:php_buildpack) { VCAP::CloudController::Buildpack.make(name: 'php_buildpack') }
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'instances' => 4, 'buildpack' => 'php_buildpack' }] }
      end

      it 'sets the buildpack' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.buildpack).to eq 'php_buildpack'
          expect(action).to eq app_apply_manifest_action
        end
      end

      context 'and the value of buildpack is \"null\"' do
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => 'blah', 'instances' => 4, 'buildpack' => 'null' }] }
        end

        it 'should autodetect the buildpack' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

          expect(response.status).to eq(202)
          app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
          expect(app_apply_manifest_jobs.count).to eq(1)

          expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |_, message, _|
            expect(message.app_update_message.buildpack_data.buildpacks).to eq([])
          end
        end
      end

      context 'for a docker app' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => 'blah', 'buildpack' => 'php_buildpack' }] }
        end

        it 'returns an error' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

          expect(response.status).to eq(422)
          errors = parsed_body['errors']
          expect(errors.size).to eq(1)
          expect(errors.map { |h| h.reject { |k, _| k == 'test_mode_info' } }).to match_array([
            {
              'detail' => 'Buildpack cannot be configured for a docker lifecycle app.',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }
          ])
        end
      end
    end

    context 'when the request body includes a buildpacks' do
      let!(:php_buildpack) { VCAP::CloudController::Buildpack.make(name: 'php_buildpack') }
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'instances' => 4, 'buildpacks' => ['php_buildpack'] }] }
      end

      it 'sets the buildpacks' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.buildpacks).to eq ['php_buildpack']
          expect(action).to eq app_apply_manifest_action
        end
      end

      context 'for a docker app' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => 'blah', 'buildpacks' => ['php_buildpack'] }] }
        end

        it 'returns an error' do
          post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

          expect(response.status).to eq(422)
          errors = parsed_body['errors']
          expect(errors.size).to eq(1)
          expect(errors.map { |h| h.reject { |k, _| k == 'test_mode_info' } }).to match_array([
            {
              'detail' => 'Buildpacks cannot be configured for a docker lifecycle app.',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008
            }
          ])
        end
      end
    end

    context 'when the request body includes a stack' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'stack' => 'cflinuxfs2' }] }
      end

      it 'sets the stack' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.stack).to eq 'cflinuxfs2'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a command' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'command' => 'run-me.sh' }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.command).to eq 'run-me.sh'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a health-check-type' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'health-check-type' => 'process' }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.health_check_type).to eq 'process'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a health-check-http-endpoint' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'health-check-http-endpoint' => '/health' }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.health_check_http_endpoint).to eq '/health'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a health-check-invocation-timeout' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'health-check-invocation-timeout' => 55 }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.health_check_invocation_timeout).to eq 55
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a timeout' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'timeout' => 9001 }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.timeout).to eq 9001
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes an environment variable' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'env' => { 'KEY100' => 'banana' } }] }
      end

      it 'sets the environment' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.env).to eq({ KEY100: 'banana' })
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a valid route' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'routes' => [{ 'route' => 'potato.yolo.io' }] }] }
      end

      it 'sets the route' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
          expect(app_guid).to eq app_model.guid
          expect(message.routes).to eq([{ route: 'potato.yolo.io' }])
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    it 'successfully scales the app in a background job' do
      post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

      expect(response.status).to eq(202)
      app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
      expect(app_apply_manifest_jobs.count).to eq 1

      expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message, action|
        expect(app_guid).to eq app_model.guid
        expect(message.instances).to eq 2
        expect(action).to eq app_apply_manifest_action
      end
    end

    it 'creates a job to track the applying the app manifest and returns it in the location header' do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

      expect {
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml
      }.to change {
        VCAP::CloudController::PollableJobModel.count
      }.by(1)

      job          = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('app.apply_manifest')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(app_model.guid)
      expect(job.resource_type).to eq('app')

      expect(response.status).to eq(202)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end

    describe 'emitting an audit event' do
      let(:app_event_repository) { instance_double(VCAP::CloudController::Repositories::AppEventRepository) }
      let(:request_body) do
        { 'applications' => [{ 'name' => 'blah', 'buildpacks' => ['ruby_buildpack', 'go_buildpack'] }] }
      end

      before do
        allow(VCAP::CloudController::Repositories::AppEventRepository).
          to receive(:new).and_return(app_event_repository)
        allow(app_event_repository).to receive(:record_app_apply_manifest)
      end

      it 'emits an "App Apply Manifest" audit event' do
        post :apply_manifest, params: { guid: app_model.guid }.merge(request_body), as: :yaml

        expect(app_event_repository).to have_received(:record_app_apply_manifest).
          with(app_model, app_model.space, instance_of(VCAP::CloudController::UserAuditInfo), request_body.to_yaml)
      end
    end
  end

  describe '#show' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    let(:expected_yml_manifest) do
      {
        'applications' => [
          {
            'name' => app_model.name,
            'stack' => app_model.lifecycle_data.stack,
          }
        ]
      }.to_yaml
    end

    before do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)
    end

    it 'returns a 200' do
      get :show, params: { guid: app_model.guid }
      expect(response.status).to eq(200)
    end

    it 'returns a YAML manifest for the app' do
      get :show, params: { guid: app_model.guid }
      expect(response.body).to eq(expected_yml_manifest)
      expect(response.headers['Content-Type']).to eq('application/x-yaml; charset=utf-8')
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) { {
          'admin' => 200,
          'admin_read_only' => 200,
          'global_auditor' => 403,
          'space_developer' => 200,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'org_auditor' => 404,
          'org_billing_manager' => 404,
        } }
        let(:api_call) { lambda { get :show, params: { guid: app_model.guid } } }
      end
    end
  end
end
