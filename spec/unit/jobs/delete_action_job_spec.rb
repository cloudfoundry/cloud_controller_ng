require 'spec_helper'

module VCAP::CloudController
  module Jobs
    describe DeleteActionJob do
      let(:user) { User.make(admin: true) }
      let(:delete_action) { SpaceDelete.new(user.id, 'admin@example.com') }
      let(:space) { Space.make(name: Sham.guid) }

      subject(:job) { DeleteActionJob.new(Space, space.guid, delete_action) }

      it { is_expected.to be_a_valid_job }

      it 'calls the delete method on the delete_action object' do
        job.perform

        expect(Space.first(id: space.id)).to be_nil
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_action_job)
      end

      context 'when deleting a space' do
        it 'has a custom timeout API error message' do
          expect(job.timeout_error).to be_a(VCAP::Errors::ApiError)
          expect(job.timeout_error.message).to eq("Deletion of space #{space.name} timed out before all resources within could be deleted")
        end
      end

      context 'when not deleting a space' do
        let(:app) { AppFactory.make }
        subject(:job) { DeleteActionJob.new(App, app.guid, AppDelete.new(user.id, 'admin@example.com')) }

        it 'does not have a custom error message' do
          expect(job.timeout_error).to be_a(VCAP::Errors::ApiError)
          expect(job.timeout_error.message).to eq('The job execution has timed out.')
        end
      end

      context 'when the delete action fails with one error' do
        let(:service_instance_1) { ManagedServiceInstance.make(:v2, space: space) }

        before do
          stub_deprovision(service_instance_1, status: 500)
        end

        it 'raises the same exception that was originally returned' do
          expect { job.perform }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse) do |error|
            instance_url = remove_basic_auth(service_instance_deprovision_url(service_instance_1))

            expect(error.message).to include("The service broker returned an invalid response for the request to #{instance_url}")
          end
        end
      end

      context 'when the delete action fails with multiple errors' do
        let(:service_instance_1) { ManagedServiceInstance.make(:v2, space: space) }
        let(:service_instance_2) { ManagedServiceInstance.make(:v2, space: space) }

        before do
          stub_deprovision(service_instance_1, status: 500)
          stub_deprovision(service_instance_2, status: 500)
        end

        it 'raises an error that contains all the error messages that were generated' do
          expect { job.perform }.to raise_error(VCAP::CloudController::DeletionError) do |error|
            instance_1_url = remove_basic_auth(service_instance_deprovision_url(service_instance_1))
            instance_2_url = remove_basic_auth(service_instance_deprovision_url(service_instance_2))

            expect(error.message).to include("The service broker returned an invalid response for the request to #{instance_1_url}")
            expect(error.message).to include("The service broker returned an invalid response for the request to #{instance_2_url}")
          end
        end
      end

      def remove_basic_auth(url)
        uri = URI(url)
        uri.user = nil
        uri.password = nil
        uri.query = nil
        uri.to_s
      end
    end
  end
end
