require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Health' do
    describe 'GET /healthz' do
      context 'the cloud controller is healthy' do
        it 'returns a 200' do
          get '/healthz'

          expect(last_response).to have_http_status(:ok)
        end
      end
    end
  end
end
