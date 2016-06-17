require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::JobsController do
    let(:job) { Delayed::Job.enqueue double(perform: nil) }
    let(:job_request_id) { job.guid }
    let(:user) { User.make }

    describe 'GET /v2/jobs/:guid' do
      context 'permissions' do
        context 'when the user does not have cc.read' do
          it 'returns a 403 unauthorized error' do
            set_current_user(user, scopes: ['cloud_controller.write'])
            get "/v2/jobs/#{job_request_id}"
            expect(last_response.status).to eq(403)
            expect(last_response.body).to match /InsufficientScope/
          end
        end

        context 'when the user has cc.read' do
          it 'allows the user to access the job' do
            set_current_user(user, scopes: ['cloud_controller.read'])
            get "/v2/jobs/#{job_request_id}"
            expect(last_response.status).to eq(200)
          end
        end

        context 'when the user is an admin' do
          it 'allows the user to access the job' do
            set_current_user(user, scopes: ['cloud_controller.admin'])
            get "/v2/jobs/#{job_request_id}"
            expect(last_response.status).to eq(200)
          end
        end
      end

      subject { get "/v2/jobs/#{job_request_id}" }

      context 'when the job exists' do
        it 'returns job' do
          set_current_user(user)
          subject
          expect(last_response.status).to eq 200
          expect(decoded_response(symbolize_keys: true)).to eq(
            ::JobPresenter.new(job).to_hash
          )
          expect(decoded_response(symbolize_keys: true)[:metadata][:guid]).not_to be_nil
        end
      end

      context "when the job doesn't exist" do
        let(:job) { nil }
        let(:job_request_id) { 123 }

        it 'returns that job was finished' do
          set_current_user(user)
          subject
          expect(last_response.status).to eq 200
          expect(decoded_response(symbolize_keys: true)).to eq(
            ::JobPresenter.new(job).to_hash
          )
        end
      end
    end
  end
end
