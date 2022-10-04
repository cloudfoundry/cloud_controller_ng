require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ResourceMatchesController do
    include_context 'resource pool'

    before do
      @resource_pool.add_directory(@tmpdir)
    end

    def resource_match_request(verb, path, matches, non_matches)
      user = User.make(admin: false, active: true)
      req = MultiJson.dump(matches + non_matches)

      set_current_user(user)
      send(verb, path, req, headers_for(user))

      resp = MultiJson.load(last_response.body)
      expect(resp).to eq(matches)

      expect(last_response.status).to eq(200)
    end

    describe 'when the app_bits_upload feature flag is enabled' do
      before do
        FeatureFlag.make(name: 'app_bits_upload', enabled: true)
      end

      describe 'PUT /v2/resource_match' do
        it 'should return an empty list when no resources match' do
          resource_match_request(:put, '/v2/resource_match', [], [@nonexisting_descriptor])
        end

        it 'should return a resource that matches' do
          resource_match_request(:put, '/v2/resource_match', [@descriptors.first], [@nonexisting_descriptor])
        end

        it 'should return many resources that match' do
          resource_match_request(:put, '/v2/resource_match', @descriptors, [@nonexisting_descriptor])
        end

        context 'invalid json' do
          it 'returns an error' do
            set_current_user_as_admin

            put '/v2/resource_match', 'invalid json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/MessageParseError/)
          end
        end

        context 'non-array json' do
          it 'returns an error' do
            set_current_user_as_admin

            put '/v2/resource_match', 'null'

            expect(last_response.status).to eq(422)
            expect(last_response.body).to match(/UnprocessableEntity/)
            expect(last_response.body).to match(/must be an array./)
          end
        end
      end
    end

    describe 'when the app_bits_upload feature flag is disabled' do
      before do
        FeatureFlag.make(name: 'app_bits_upload', enabled: false)
      end

      it 'allows the upload if the user is an admin' do
        set_current_user_as_admin

        put '/v2/resource_match', '[]'
        expect(last_response.status).to eq(200)
      end

      it 'returns FeatureDisabled unless the user is an admin' do
        set_current_user(User.make)

        put '/v2/resource_match', '[]'

        expect(last_response.status).to eq(403)
        expect(decoded_response['error_code']).to match(/FeatureDisabled/)
        expect(decoded_response['description']).to match(/Feature Disabled/)
      end
    end

    describe 'when the resource_matching flag is disabled' do
      before do
        FeatureFlag.make(name: 'resource_matching', enabled: false)
      end

      it 'should return an empty list' do
        resource_match_request(:put, '/v2/resource_match', [], @descriptors)
      end
    end
  end
end
