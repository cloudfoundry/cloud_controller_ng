require 'rails_helper'
require 'permissions_spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe SpaceManifestsController, type: :controller do
  describe '#apply_manifest' do
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'blah') }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let(:app_apply_manifest_action) { instance_double(VCAP::CloudController::AppApplyManifest) }
    let(:request_body) { { 'applications' => [{ 'name' => app_model.name, 'instances' => 2 }] } }

    before do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)
      allow(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to receive(:new).and_call_original
      allow(VCAP::CloudController::AppApplyManifest).to receive(:new).and_return(app_apply_manifest_action)
      request.headers['CONTENT_TYPE'] = 'application/x-yaml'
    end

    describe 'permissions' do
      context 'when the user cannot read from the space' do
        let(:user_from_another_space) { VCAP::CloudController::User.make }

        before do
          set_current_user(user_from_another_space)
        end

        it 'raises an ApiError with a 404 code' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have .write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the space does not exist' do
        role_to_expected_http_response = {
          'admin' => 404,
          'admin_read_only' => 404,
          'global_auditor' => 404,
          'space_developer' => 404,
          'space_manager' => 404,
          'space_auditor' => 404,
          'org_manager' => 404,
          'org_auditor' => 404,
          'org_billing_manager' => 404
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role: role,
                org: org,
                space: space,
                user: user,
                scopes: %w[cloud_controller.read cloud_controller.write]
              )

              post :apply_manifest, params: { guid: 'non-existent' }, body: request_body.to_yaml, as: :yaml

              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            end
          end
        end
      end

      context 'When the space exists' do
        role_to_expected_http_response = {
          'admin' => 202,
          'admin_read_only' => 403,
          'global_auditor' => 403,
          'space_developer' => 202,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'org_auditor' => 404,
          'org_billing_manager' => 404
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role: role,
                org: org,
                space: space,
                user: user,
                scopes: %w[cloud_controller.read cloud_controller.write]
              )

              post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            end
          end
        end
      end
    end

    context 'when the request body is invalid' do
      context 'when the yaml is missing an applications array' do
        let(:request_body) { { 'name' => 'blah', 'instances' => 4 } }

        it 'returns a 422' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context 'when the requested applications array is empty' do
        let(:request_body) { { 'applications' => [] } }

        it 'returns a 422' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context 'when specified manifest fails validations' do
        let(:request_body) do
          { 'applications' => [{ 'name' => 'blah', 'instances' => -1, 'memory' => '10NOTaUnit',
                                 'command' => '', 'env' => 42,
                                 'health-check-http-endpoint' => '/endpoint',
                                 'health-check-invocation-timeout' => -22,
                                 'health-check-type' => 'foo',
                                 'readiness_health-check-http-endpoint' => 'potato-potahto',
                                 'readiness_health-check-invocation-timeout' => -2,
                                 'readiness_health-check-type' => 'meow',
                                 'timeout' => -42,
                                 'random-route' => -42,
                                 'routes' => [{ 'route' => 'garbage' }] }] }
        end

        it 'returns a 422 and validation errors' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml
          expect(response).to have_http_status(:unprocessable_content)
          errors = parsed_body['errors']
          expect(errors.size).to eq(14)
          def error_message(detail)
            { 'detail' => detail, 'title' => 'CF-UnprocessableEntity', 'code' => 10_008 }
          end

          messages = [
            'For application \'blah\': Process "web": Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
            'For application \'blah\': Process "web": Instances must be greater than or equal to 0',
            'For application \'blah\': Process "web": Command must be between 1 and 4096 characters',
            'For application \'blah\': Env must be an object of keys and values',
            'For application \'blah\': Process "web": Health check type must be "http" to set a health check HTTP endpoint',
            'For application \'blah\': Process "web": Health check type must be "port", "process", or "http"',
            'For application \'blah\': Process "web": Health check invocation timeout must be greater than or equal to 1',
            'For application \'blah\': Process "web": Readiness health check type must be "http" to set a health check HTTP endpoint',
            'For application \'blah\': Process "web": Readiness health check type must be "port", "process", or "http"',
            'For application \'blah\': Process "web": Readiness health check invocation timeout must be greater than or equal to 1',
            'For application \'blah\': Process "web": Readiness health check http endpoint must be a valid URI path',
            'For application \'blah\': Process "web": Timeout must be greater than or equal to 1',
            "For application 'blah': The route 'garbage' is not a properly formed URL",
            'For application \'blah\': Random-route must be a boolean'
          ]

          expect(errors.map { |h| h.except('test_mode_info') }).to match_array(messages.map { |message| error_message(message) })
        end
      end

      context 'when the request payload is not yaml' do
        let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 1 }] } }

        before do
          allow(CloudController::Errors::ApiError).to receive(:new_from_details).and_call_original
          request.headers['CONTENT_TYPE'] = 'text/plain'
        end

        it 'returns a 400' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml
          expect(response).to have_http_status(:bad_request)
          # Verify we're getting the InvalidError we're expecting
          expect(CloudController::Errors::ApiError).to have_received(:new_from_details).with('BadRequest', 'Content-Type must be yaml').exactly :once
        end
      end

      context 'when the request is missing a name' do
        let(:request_body) do
          { 'applications' => [{ 'instances' => 4 }] }
        end

        it 'returns a 422' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml
          expect(response).to have_http_status(:unprocessable_content)
          parsed_response = Oj.load(response.body)
          expect(parsed_response['errors'][0]['detail']).to match(/For application at index 0:/)
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].buildpack).to eq 'php_buildpack'
          expect(action).to eq app_apply_manifest_action
        end
      end

      context 'and the value of buildpack is \"null\"' do
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => 'blah', 'instances' => 4, 'buildpack' => 'null' }] }
        end

        it 'autodetects the buildpack' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:accepted)
          space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
          expect(space_apply_manifest_jobs.count).to eq(1)

          expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |_, app_guid_message_hash, _|
            expect(app_guid_message_hash.entries.first[1].app_update_message.buildpack_data.buildpacks).to eq([])
          end
        end
      end

      context 'for a docker app' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker, name: 'blah') }
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => app_model.name, 'buildpack' => 'php_buildpack' }] }
        end

        it 'returns an error' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:unprocessable_content)
          errors = parsed_body['errors']
          expect(errors.size).to eq(1)
          expected_error = [
            { 'detail' => "For application 'blah': Buildpack cannot be configured for a docker lifecycle app.",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10_008 }
          ]
          expect(errors.map { |h| h.except('test_mode_info') }).to match_array(expected_error)
        end
      end
    end

    context 'when the request body includes buildpacks' do
      let!(:php_buildpack) { VCAP::CloudController::Buildpack.make(name: 'php_buildpack') }
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'instances' => 4, 'buildpacks' => ['php_buildpack'] }] }
      end

      it 'sets the buildpacks' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].buildpacks).to eq ['php_buildpack']
          expect(action).to eq app_apply_manifest_action
        end
      end

      context 'for a docker app' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker, name: 'blah') }
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => app_model.name, 'buildpacks' => ['php_buildpack'] }] }
        end

        it 'returns an error' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:unprocessable_content)
          errors = parsed_body['errors']
          expect(errors.size).to eq(1)
          expected_error = [
            { 'detail' => "For application 'blah': Buildpacks cannot be configured for a docker lifecycle app.",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10_008 }
          ]
          expect(errors.map { |h| h.except('test_mode_info') }).to match_array(expected_error)
        end
      end

      context 'when the buildpack does not exist' do
        let(:request_body) do
          { 'applications' =>
            [{ 'name' => 'burger-king', 'instances' => 4, 'buildpacks' => ['badpack'] }] }
        end

        it 'returns a 422 and a useful error to the user' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:unprocessable_content)
          space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
          expect(space_apply_manifest_jobs.count).to eq 0

          errors = parsed_body['errors']
          expect(errors.size).to eq(1)
          expect(errors.map { |h| h.except('test_mode_info') }).to contain_exactly({
                                                                                     'detail' => "For application 'burger-king': Specified unknown buildpack name: \"badpack\"",
                                                                                     'title' => 'CF-UnprocessableEntity',
                                                                                     'code' => 10_008
                                                                                   })
        end
      end
    end

    context 'when the request body includes docker' do
      let(:request_body) do
        { 'applications' =>
              [{ 'name' => 'blah', 'docker' => { 'image' => 'my/image' } }] }
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
      end

      context 'for a docker app' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker, name: 'blah') }

        it 'sets the docker image' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:accepted)
          space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
          expect(space_apply_manifest_jobs.count).to eq 1

          expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
            expect(aspace).to eq space
            expect(app_guid_message_hash.entries.first[1].docker[:image]).to eq 'my/image'
            expect(action).to eq app_apply_manifest_action
          end
        end
      end

      context 'for a buildpack app' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:buildppack, name: 'blah') }

        it 'returns an error' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:unprocessable_content)
          errors = parsed_body['errors']
          expect(errors.size).to eq(1)
          expected_error = [{
            'detail' => "For application 'blah': Docker cannot be configured for a buildpack lifecycle app.",
            'title' => 'CF-UnprocessableEntity',
            'code' => 10_008
          }]
          expect(errors.map { |h| h.except('test_mode_info') }).to match_array(expected_error)
        end
      end
    end

    context 'when the request body includes a stack' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'stack' => 'cflinuxfs4' }] }
      end

      it 'sets the stack' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].stack).to eq 'cflinuxfs4'
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].command).to eq 'run-me.sh'
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].health_check_type).to eq 'process'
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].health_check_http_endpoint).to eq '/health'
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].health_check_invocation_timeout).to eq 55
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a readiness-health-check-type' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'readiness-health-check-type' => 'process' }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].readiness_health_check_type).to eq 'process'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a readiness-health-check-http-endpoint' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'readiness-health-check-http-endpoint' => '/ready' }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].readiness_health_check_http_endpoint).to eq '/ready'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a readiness-health-check-invocation-timeout' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'readiness-health-check-invocation-timeout' => 55 }] }
      end

      it 'sets the command' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].readiness_health_check_invocation_timeout).to eq 55
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].timeout).to eq 9001
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes metadata' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah',
             'metadata' => {
               'labels' => {
                 'potato' => 'idaho',
                 'myspace.com/songs' => 'missing'
               },
               'annotations' => {
                 'potato' => 'yam',
                 'juice' => 'newton'
               }
             } },
           { 'name' => 'choo',
             'metadata' => {
               'labels' => {
                 'potato' => 'idaho',
                 'myspace.com/songs' => nil
               },
               'annotations' => {
                 'potato' => nil,
                 'juice' => 'newton'
               }
             } }] }
      end

      it 'applies the metadata' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace.guid).to eq space.guid
          app_update_message = app_guid_message_hash.entries.first[1].app_update_message
          expect(app_update_message.labels).to eq({
                                                    potato: 'idaho',
                                                    'myspace.com/songs': 'missing'
                                                  })
          expect(app_update_message.annotations).to eq({
                                                         potato: 'yam',
                                                         juice: 'newton'
                                                       })

          app_update_message = app_guid_message_hash.entries[1][1].app_update_message
          expect(app_update_message.labels).to eq({
                                                    potato: 'idaho',
                                                    'myspace.com/songs': nil
                                                  })
          expect(app_update_message.annotations).to eq({
                                                         potato: nil,
                                                         juice: 'newton'
                                                       })

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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].env).to eq({ KEY100: 'banana' })
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
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(response).to have_http_status(:accepted)
        space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
        expect(space_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
          expect(aspace).to eq space
          expect(app_guid_message_hash.entries.first[1].routes).to eq([{ route: 'potato.yolo.io' }])
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    it 'successfully scales the app in a background job' do
      post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

      expect(response).to have_http_status(:accepted)
      space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
      expect(space_apply_manifest_jobs.count).to eq 1

      expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
        expect(aspace).to eq space
        expect(app_guid_message_hash.entries.first[1].instances).to eq 2
        expect(action).to eq app_apply_manifest_action
      end
    end

    it 'creates a job to track the applying the app manifest and returns it in the location header' do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

      expect do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml
      end.to change(VCAP::CloudController::PollableJobModel, :count).by(1)

      job = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('space.apply_manifest')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(space.guid)
      expect(job.resource_type).to eq('space')

      expect(response).to have_http_status(:accepted)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end

    describe 'emitting an audit event' do
      let(:request_body) do
        { 'applications' => [{ 'name' => 'blah', 'buildpacks' => %w[ruby_buildpack go_buildpack] }] }
      end
      let(:app_event_repository) { instance_double(VCAP::CloudController::Repositories::AppEventRepository) }

      before do
        allow(VCAP::CloudController::Repositories::AppEventRepository).
          to receive(:new).and_return(app_event_repository)
        allow(app_event_repository).to receive(:record_app_apply_manifest)
      end

      it 'emits an "App Apply Manifest" audit event' do
        post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

        expect(app_event_repository).to have_received(:record_app_apply_manifest).
          with(app_model, app_model.space, instance_of(VCAP::CloudController::UserAuditInfo), request_body.to_yaml)
      end
    end

    context 'when there are multiple apps' do
      context 'when the apps exist' do
        let(:app1) { VCAP::CloudController::AppModel.make(name: 'honey', space: space) }
        let(:app2) { VCAP::CloudController::AppModel.make(name: 'nut', space: space) }
        let(:request_body) do
          { 'applications' => [
            { 'name' => app1.name, 'instances' => 2 },
            { 'name' => app2.name, 'instances' => 4 }
          ] }
        end

        context 'when there are manifest is invalid' do
          let(:request_body) do
            { 'applications' => [
              { 'name' => app1.name, 'instances' => -1 },
              { 'name' => app2.name, 'memory' => '10NOTaUnit' }
            ] }
          end

          it 'returns manifest errors associated with their apps' do
            post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml
            expect(response).to have_http_status(:unprocessable_content)
            errors = parsed_body['errors']
            expect(errors.size).to eq(2)
            processed_errors = errors.map { |h| h.except('test_mode_info') }

            expected_errors = [{
              'detail' => 'For application \'honey\': Process "web": Instances must be greater than or equal to 0',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10_008
            }, {
              'detail' => 'For application \'nut\': Process "web": Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10_008
            }]

            expect(processed_errors).to match_array(expected_errors)
          end
        end

        it 'successfully scales all apps in a single background job' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          expect(response).to have_http_status(:accepted)
          space_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%SpaceApplyManifest%'"))
          expect(space_apply_manifest_jobs.count).to eq 1

          expect(VCAP::CloudController::Jobs::SpaceApplyManifestActionJob).to have_received(:new) do |aspace, app_guid_message_hash, action|
            expect(aspace.guid).to eq space.guid
            expect(app_guid_message_hash.keys).to eq([app1.guid, app2.guid])
            expect(app_guid_message_hash.values.map(&:instances)).to eq([2, 4])
            expect(action).to eq app_apply_manifest_action
          end
        end

        it 'emits an "App Apply Manifest" audit event for each app' do
          post :apply_manifest, params: { guid: space.guid }, body: request_body.to_yaml, as: :yaml

          app_events = VCAP::CloudController::Event.where(actee_type: 'app')
          expect(app_events.count).to eq(2)
          expect(app_events.map(&:actee)).to contain_exactly(app1.guid, app2.guid)
          metadatas = app_events.map { |e| Psych.safe_load(e.metadata['request']['manifest'], permitted_classes: [ActiveSupport::HashWithIndifferentAccess], strict_integer: true) }
          expect(metadatas.map { |m| m['applications'].first['instances'] }).to contain_exactly(2, 4)
        end
      end
    end
  end
end
