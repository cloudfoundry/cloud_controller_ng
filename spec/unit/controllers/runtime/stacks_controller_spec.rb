require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::StacksController do
    let(:user) { User.make }

    before do
      set_current_user(user, admin: true)
    end

    describe 'Query Parameters' do
      it { expect(VCAP::CloudController::StacksController).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(VCAP::CloudController::StacksController).to have_creatable_attributes({
                                                                                       name: { type: 'string', required: true },
                                                                                       description: { type: 'string', required: false }
                                                                                     })
      end
    end

    describe 'POST /v2/stacks' do
      let(:params) { { name: 'zakstack', description: 'the_best_of_all_the_stacks' } }

      before do
        set_current_user(user)
      end

      context 'as an admin' do
        before do
          set_current_user_as_admin
        end

        it 'creates a stack' do
          post '/v2/stacks', MultiJson.dump(params)
          expect(last_response).to have_http_status(:created)
        end

        context 'when the description is not provided' do
          let(:params) { { name: 'zakstack' } }

          it 'creates a stack' do
            post '/v2/stacks', MultiJson.dump(params)
            expect(last_response).to have_http_status(:created)
          end
        end
      end

      it 'returns unauthorized' do
        post '/v2/stacks', MultiJson.dump(params)
        expect(last_response).to have_http_status(:forbidden)
      end
    end

    describe '#delete' do
      let(:stack) { Stack.make }

      context 'if no app exist' do
        it 'succeds' do
          delete "/v2/stacks/#{stack.guid}"
          expect(last_response).to have_http_status(:no_content)
        end
      end

      context 'if apps exist' do
        let!(:process) { ProcessModelFactory.make(stack:) }

        it 'fails even when recursive' do
          delete "/v2/stacks/#{stack.guid}?recursive=true"
          expect(parsed_response['code']).to eq 10_006
          expect(last_response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
