require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PrivateStacksController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          description: { type: 'string' },
          organization_guids: { type: '[string]' },
          space_guids: { type: '[string]' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          description: { type: 'string' },
          organization_guids: { type: '[string]' },
          space_guids: { type: '[string]' }
        })
      end
    end

    describe 'Associations' do
      describe 'nested routes' do
        it do
          expect(described_class).to have_nested_routes({ organizations: [:get, :put, :delete], spaces: [:get, :put, :delete] })
        end
      end
    end

    describe 'create' do
      let(:stack_name) { "newprivatestack" }
      before { set_current_user_as_admin }

      context 'when parameter is_private is not given' do
        it 'creates Stack object with is_private flag is true' do
          post '/v2/private_stacks', MultiJson.dump({ name: stack_name })
          expect(last_response.status).to eq(201)
          expect(entity['is_private']).to be_truthy
        end
      end

      context 'when parameter is_private is true' do
        it 'creates Stack object with is_private flag is true' do
          post '/v2/private_stacks', MultiJson.dump({ name: stack_name, is_private: true })
          expect(last_response.status).to eq(201)
          expect(entity['is_private']).to be_truthy
        end
      end

      context 'even when parameter is_private is false' do
        it 'creates Stack object with is_private flag is true' do
          post '/v2/private_stacks', MultiJson.dump({ name: stack_name, is_private: false })

          expect(last_response.status).to eq(201)
          expect(entity['is_private']).to be_truthy
        end
      end
    end

    describe 'associate / unassociate' do
      let(:stack) { Stack.make(is_private: true) }
      let(:org) { Organization.make }

      before do
        set_current_user_as_admin

        put "/v2/private_stacks/#{stack.guid}/organizations/#{org.guid}"
        expect(last_response.status).to eq(201)
      end

      after do
        delete "/v2/private_stacks/#{stack.guid}/organizations/#{org.guid}"
        expect(last_response.status).to eq(204)
      end

      describe 'with organization' do
        let(:space) { Space.make(organization: org) }

        before do
          put "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(201)
        end

        after do
          delete "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(204)
        end

        context 'when any space in organization is associated with private stack' do
          it 'fails to unassociate private stack with organization' do
            delete "/v2/private_stacks/#{stack.guid}/organizations/#{org.guid}"
            expect(last_response.status).to eq(400)
          end
        end
      end

      describe 'with space' do
        it 'can be associated / unassociated with space in org associated' do
          space = Space.make(organization: org)

          put "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(201)

          delete "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(204)
        end

        it 'cannot be associated with space in org not associated' do
          space = Space.make

          put "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(500)
          expect(decoded_response['description']).to match(/AssociationError/)
          expect(decoded_response['error_code']).to match(/AssociationError/)
        end

        context 'when any app with private stack exists' do
          let(:space) { Space.make(organization: org) }

          before do
            put "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
            expect(last_response.status).to eq(201)
          end

          after do
            delete "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
            expect(last_response.status).to eq(204)
          end

          it 'fails to unassociate private stack with space' do
            post "/v2/apps", MultiJson.dump(name: 'app', space_guid: space.guid, stack_guid: stack.guid)
            expect(last_response.status).to eq(201)
            app_guid = metadata['guid']

            delete "/v2/private_stacks/#{stack.guid}/spaces/#{space.guid}"
            expect(last_response.status).to eq(400)

            get "/v2/private_stacks/#{stack.guid}/spaces"
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(1)
            expect(decoded_response['resources'][0]['metadata']['guid']).to eq(space.guid)

            delete "/v2/apps/#{app_guid}"
            expect(last_response.status).to eq(204)
          end
        end
      end
    end

    describe 'errors' do
      before { set_current_user_as_admin }

      it 'returns StackInvalid' do
        post '/v2/private_stacks', MultiJson.dump({ name: "in\nvalid" })

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/stack is invalid/)
        expect(decoded_response['error_code']).to match(/StackInvalid/)
      end

      it 'returns StackNameTaken errors on unique name errors' do
        Stack.make(name: 'foo')
        post '/v2/private_stacks', MultiJson.dump({ name: "foo" })

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/name is taken/)
        expect(decoded_response['error_code']).to match(/StackNameTaken/)
      end
    end
  end
end
