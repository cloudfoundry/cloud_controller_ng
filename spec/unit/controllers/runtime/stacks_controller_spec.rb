require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::StacksController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
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
