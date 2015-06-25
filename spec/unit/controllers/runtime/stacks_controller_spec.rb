require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::StacksController do
    let(:user) { User.make }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          description: { type: 'string', required: false }
        })
      end
    end

    describe 'POST /v2/stacks' do
      let(:params) { { name: 'zakstack', description: 'the_best_of_all_the_stacks' } }
      context 'as an admin' do
        it 'creates a stack' do
          post '/v2/stacks', MultiJson.dump(params), json_headers(admin_headers)
          expect(last_response.status).to eq(201)
        end

        context 'when the description is not provided' do
          let(:params) { { name: 'zakstack' } }
          it 'creates a stack' do
            post '/v2/stacks', MultiJson.dump(params), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end
        end
      end

      it 'returns unauthorized' do
        post '/v2/stacks', MultiJson.dump(params), json_headers(headers_for(user))
        expect(last_response.status).to eq(403)
      end
    end

    describe '#delete' do
      let(:stack) { Stack.make }

      context 'if no app exist' do
        it 'succeds' do
          delete "/v2/stacks/#{stack.guid}", '', admin_headers
          expect(last_response.status).to eq(204)
        end
      end

      context 'if apps exist' do
        let!(:application) { AppFactory.make(stack: stack) }

        it 'fails even when recursive' do
          delete "/v2/stacks/#{stack.guid}?recursive=true", '', admin_headers
          expect(last_response.status).to eq(400)
        end
      end
    end
  end
end
