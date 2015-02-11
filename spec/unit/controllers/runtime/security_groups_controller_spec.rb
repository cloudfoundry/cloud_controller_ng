require 'spec_helper'

module VCAP::CloudController
  describe SecurityGroupsController do
    let(:group) { SecurityGroup.make }

    it_behaves_like 'an admin only endpoint', path: '/v2/security_groups'

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          rules: { type: '[hash]', default: [] },
          space_guids: { type: '[string]' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          rules: { type: '[hash]' },
          space_guids: { type: '[string]' }
        })
      end
    end

    describe 'Associations' do
      describe 'nested routes' do
        it do
          expect(described_class).to have_nested_routes({ spaces: [:get, :put, :delete] })
        end
      end
    end

    describe 'errors' do
      it 'returns SecurityGroupInvalid' do
        post '/v2/security_groups', '{"name":"one\ntwo"}', json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/security group is invalid/)
        expect(decoded_response['error_code']).to match(/SecurityGroupInvalid/)
      end

      it 'returns SecurityGroupNameTaken errors on unique name errors' do
        SecurityGroup.make(name: 'foo')
        post '/v2/security_groups', '{"name":"foo"}', json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/name is taken/)
        expect(decoded_response['error_code']).to match(/SecurityGroupNameTaken/)
      end
    end

    describe 'audit events' do
      it 'logs audit.security_group.delete-request when deleting a security group' do
        security_group = SecurityGroup.make
        security_group_guid = security_group.guid
        delete "/v2/security_groups/#{security_group_guid}", '', json_headers(admin_headers)

        expect(last_response.status).to eq(204)

        event = Event.find(type: 'audit.security_group.delete-request', actee: security_group_guid)
        expect(event).not_to be_nil
        expect(event.actee).to eq(security_group_guid)
        expect(event.actee_name).to eq(security_group.name)
        expect(event.organization_guid).to eq('')
        expect(event.space_guid).to eq('')
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
      end
    end
  end
end
