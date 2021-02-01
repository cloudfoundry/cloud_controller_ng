require 'spec_helper'
require 'rails_helper'

RSpec.describe ResourceMatchesController, type: :controller do
  describe '#create' do
    include_context 'resource pool'

    let(:user) { VCAP::CloudController::User.make }
    let(:req_body) do
      {
        resources: [
          {
            checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
            size_in_bytes: 36,
            path: 'path/to/file1',
            mode: '644'
          },
          {
            checksum: { value: 'a9993e364706816aba3e25717850c26c9cd0d89d' },
            size_in_bytes: 1,
            path: 'path/to/file2',
            mode: '645'
          }
        ]
      }
    end

    before do
      set_current_user_as_admin(user: user)
      @resource_pool.add_directory(@tmpdir)
    end

    describe 'permissions by role' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }

      role_to_expected_http_response = {
        'admin' => 201,
        'admin_read_only' => 403,
        'global_auditor' => 403,
        'space_developer' => 201,
        'space_manager' => 201,
        'space_auditor' => 201,
        'org_manager' => 201,
        'org_auditor' => 201,
        'org_billing_manager' => 201,
        'unauthenticated' => 401,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            post :create, params: req_body, as: :json

            expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
          end
        end
      end
    end

    context 'when resource matching feature flag is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'app_bits_upload', enabled: false)
      end

      context 'when the user is not an admin' do
        before do
          set_current_user(VCAP::CloudController::User.make)
        end

        it 'raises FeatureDisabled' do
          post :create, params: req_body, as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include 'FeatureDisabled'
          expect(response.body).to include 'Feature Disabled'
        end
      end

      context 'when the user is an admin' do
        it 'allows the upload' do
          set_current_user_as_admin

          post :create, params: req_body, as: :json

          expect(response.status).to eq(201)
        end
      end
    end

    context 'when resource matching feature flag is enabled' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'app_bits_upload', enabled: true)
      end

      context 'when no resources match' do
        let(:req_body) do
          {
            resources: [{
              checksum: { value: @nonexisting_descriptor['sha1'] },
              size_in_bytes: @nonexisting_descriptor['size']
            }]
          }
        end

        it 'should return an empty list ' do
          post :create, params: req_body, as: :json
          expect(response.status).to eq(201)
          expect(parsed_body['resources']).to eq([])
        end
      end

      context 'when resources match' do
        let(:req_body) do
          {
            resources: [
              {
                checksum: { value: @descriptors.first['sha1'] },
                size_in_bytes: @descriptors.first['size'],
                path: 'path/to/file1',
                mode: '644'
              },
              {
                checksum: { value: @nonexisting_descriptor['sha1'] },
                size_in_bytes: @nonexisting_descriptor['size'],
                path: 'path/to/file2',
                mode: '645'
              }
            ]
          }
        end

        it 'should return it' do
          post :create, params: req_body, as: :json
          expect(response.status).to eq(201)
          expect(parsed_body['resources']).to eq([{
            'checksum' => { 'value' => @descriptors.first['sha1'] },
            'size_in_bytes' => @descriptors.first['size'],
            'path' => 'path/to/file1',
            'mode' => '644'
          }])
        end
      end

      context 'when resources match' do
        let(:req_body) do
          {
            resources: [
              {
                checksum: { value: @descriptors.first['sha1'] },
                size_in_bytes: @descriptors.first['size'],
                path: 'path/to/file1',
                mode: '644'
              },
              {
                checksum: { value: @descriptors.last['sha1'] },
                size_in_bytes: @descriptors.last['size'],
                path: 'path/to/file2',
                mode: '645'
              },
              {
                checksum: { value: @nonexisting_descriptor['sha1'] },
                size_in_bytes: @nonexisting_descriptor['size'],
                path: 'path/to/file3',
                mode: '646'
              }
            ]
          }
        end

        it 'should return many resources that match' do
          post :create, params: req_body, as: :json
          expect(response.status).to eq(201)
          expect(parsed_body['resources']).to eq([
            {
              'checksum' => { 'value' => @descriptors.first['sha1'] },
              'size_in_bytes' => @descriptors.first['size'],
              'path' => 'path/to/file1',
              'mode' => '644'
            },
            {
              'checksum' => { 'value' => @descriptors.last['sha1'] },
              'size_in_bytes' => @descriptors.last['size'],
              'path' => 'path/to/file2',
              'mode' => '645'
            }
          ])
        end
      end

      context 'fails validations' do
        it 'returns an error' do
          post :create, params: { 'wrong-key' => [] }, as: :json

          expect(response.status).to eq(422)
        end
      end
    end
  end
end
