require 'spec_helper'

module VCAP::CloudController
  describe BuildpacksCacheController do
    describe 'DELETE /v2/blobstores/buildpack_cache' do
      it 'returns the job' do
        expect {
          delete '/v2/blobstores/buildpack_cache', {}, admin_headers
        }.to change {
          Delayed::Job.count
        }.by(1)

        job = Delayed::Job.last

        expect(last_response.status).to eq(202)
        expect(decoded_response(symbolize_keys: true)).to eq(JobPresenter.new(job).to_hash)
      end

      context 'when the user is not an admin' do
        let(:user) { User.make }
        it 'returns a 403 NotAuthorized' do
          delete '/v2/blobstores/buildpack_cache', {}, headers_for(user)

          expect(last_response.status).to eq(403)
          expect(last_response.body).to match('CF-NotAuthorized')
        end
      end
    end
  end
end
