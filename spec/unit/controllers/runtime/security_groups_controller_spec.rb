require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SecurityGroupsController do
    let(:group) { SecurityGroup.make }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          rules: { type: '[hash]', default: [] },
          space_guids: { type: '[string]' },
          staging_space_guids: { type: '[string]' },
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          rules: { type: '[hash]' },
          space_guids: { type: '[string]' },
          staging_space_guids: { type: '[string]' },
        })
      end
    end

    describe 'Associations' do
      describe 'nested routes' do
        it do
          expect(described_class).to have_nested_routes({
            spaces: [:get, :put, :delete],
            staging_spaces: [:get, :put, :delete],
          })
        end
      end
    end

    describe 'errors' do
      before { set_current_user_as_admin }

      it 'returns SecurityGroupInvalid' do
        post '/v2/security_groups', '{"name":"one\ntwo"}'

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/security group is invalid/)
        expect(decoded_response['error_code']).to match(/SecurityGroupInvalid/)
      end

      it 'returns SecurityGroupNameTaken errors on unique name errors' do
        SecurityGroup.make(name: 'foo')
        post '/v2/security_groups', '{"name":"foo"}'

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/name is taken/)
        expect(decoded_response['error_code']).to match(/SecurityGroupNameTaken/)
      end

      context 'when the max length for security groups is exceeded' do
        let(:long_rule) do
          {
            'protocol' => 'all',
            'destination' => '0.0.0.0/0'
          }
        end
        let(:security_group) do
          {
            'name' => 'foo',
            'rules' => [long_rule]
          }
        end

        before do
          stub_const('VCAP::CloudController::SecurityGroup::MAX_RULES_CHAR_LENGTH', 20)
        end

        it 'returns SecurityGroupInvalid' do
          post '/v2/security_groups', MultiJson.dump(security_group)

          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to match(/must not exceed #{SecurityGroup::MAX_RULES_CHAR_LENGTH} characters/)
          expect(decoded_response['error_code']).to match(/SecurityGroupInvalid/)
        end
      end
    end

    describe 'spaces' do
      let(:user) { User.make }
      let(:org) { Organization.make(user_guids: [user.guid]) }
      let(:space) { Space.make(organization: org) }
      let(:security_group) { SecurityGroup.make }

      before do
        set_current_user(user)
      end

      context 'as admin' do
        before do
          set_current_user_as_admin(user: user)
        end

        it 'works for staging security groups' do
          put "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/security_groups/#{security_group.guid}/staging_spaces", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(space.guid)

          delete "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 204
        end

        it 'works for running security groups' do
          put "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/security_groups/#{security_group.guid}/spaces", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(space.guid)

          delete "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 204
        end
      end

      context 'as org manager' do
        before do
          org.add_manager(user)
        end

        it 'works for staging security groups' do
          put "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          get "/v2/security_groups/#{security_group.guid}/staging_spaces", nil
          expect(last_response.status).to eq 403

          delete "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end

        it 'works for running security groups' do
          put "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          get "/v2/security_groups/#{security_group.guid}/spaces", nil
          expect(last_response.status).to eq 403

          delete "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end
      end

      context 'as space manager' do
        before do
          space.add_manager(user)
        end

        it 'works for staging security groups' do
          put "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          space.add_staging_security_group(security_group)

          get "/v2/security_groups/#{security_group.guid}/staging_spaces", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(space.guid)

          delete "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end

        it 'works for running security groups' do
          put "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          space.add_security_group(security_group)

          get "/v2/security_groups/#{security_group.guid}/spaces", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(space.guid)

          delete "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end
      end

      context 'as space developer' do
        before do
          space.add_developer(user)
        end

        it 'works for staging security groups' do
          put "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          space.add_staging_security_group(security_group)

          get "/v2/security_groups/#{security_group.guid}/staging_spaces", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(space.guid)

          delete "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end

        it 'works for running security groups' do
          put "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          space.add_security_group(security_group)

          get "/v2/security_groups/#{security_group.guid}/spaces", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(space.guid)

          delete "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end
      end

      context 'as space auditor' do
        before do
          space.add_auditor(user)
        end

        it 'works for staging security groups' do
          put "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          get "/v2/security_groups/#{security_group.guid}/staging_spaces", nil
          expect(last_response.status).to eq 403

          delete "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end

        it 'works for running security groups' do
          put "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403

          get "/v2/security_groups/#{security_group.guid}/spaces", nil
          expect(last_response.status).to eq 403

          delete "/v2/security_groups/#{security_group.guid}/spaces/#{space.guid}", nil
          expect(last_response.status).to eq 403
        end
      end
    end
  end
end
