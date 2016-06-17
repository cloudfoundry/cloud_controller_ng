require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpacksCacheController do
    describe 'DELETE /v2/blobstores/buildpack_cache' do
      before { set_current_user_as_admin }

      it 'returns the job' do
        expect {
          delete '/v2/blobstores/buildpack_cache'
        }.to change {
          Delayed::Job.count
        }.by(1)

        job = Delayed::Job.last

        expect(last_response.status).to eq(202)
        expect(decoded_response(symbolize_keys: true)).to eq(JobPresenter.new(job).to_hash)
      end

      context 'when the user is not an admin' do
        before { set_current_user(User.make) }

        it 'returns a 403 NotAuthorized' do
          delete '/v2/blobstores/buildpack_cache'

          expect(last_response.status).to eq(403)
          expect(last_response.body).to match('CF-NotAuthorized')
        end
      end
    end
  end
end
