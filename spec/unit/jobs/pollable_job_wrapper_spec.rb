require 'spec_helper'
require 'jobs/pollable_job_wrapper'
require 'yaml'

module VCAP::CloudController::Jobs
  class BigException < StandardError
  end

  RSpec.describe PollableJobWrapper, job_context: :worker do
    let(:job) { double(job_name_in_configuration: 'my-job', max_attempts: 2, perform: nil) }
    let(:pollable_job) { PollableJobWrapper.new(job) }

    describe '#perform' do
      it 'runs the provided job' do
        expect(job).to receive(:perform)
        pollable_job.perform
      end
    end

    describe 'delayed job hooks' do
      # using a real job as DelayedJob has trouble marshalling doubles
      let(:delete_action) { VCAP::CloudController::DropletDelete.new('fake') }
      let(:job) { DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake', delete_action) }

      it 'creates a job record and marks the job model as completed' do
        enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)

        job_record = VCAP::CloudController::PollableJobModel.find(delayed_job_guid: enqueued_job.guid)
        expect(job_record).not_to be_nil, "Expected to find PollableJobModel with delayed_job_guid '#{enqueued_job.guid}', but did not"
        expect(job_record.state).to eq('PROCESSING')
        expect(job_record.operation).to eq('droplet.delete')
        expect(job_record.resource_guid).to eq('fake')
        expect(job_record.resource_type).to eq('droplet')
        expect(job_record.cf_api_error).to be_nil

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(job_record.reload.state).to eq('COMPLETE')
      end

      context 'when dynamic job priorities are enabled' do
        before do
          TestConfig.config[:jobs][:enable_dynamic_job_priorities] = true
        end

        context 'when there are several active jobs for the current user' do
          let(:security_context) { double({ current_user_email: 'user-email', current_user_name: 'user-name', current_user: double({ guid: 'user-guid' }) }) }
          let(:pollable_job) { PollableJobWrapper.new(job) }

          before do
            stub_const('VCAP::CloudController::SecurityContext', security_context)
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
          end

          it 'adds +1 to base priority for each active job' do
            TestConfig.config[:jobs][:priorities] = { 'droplet.delete': 20 }

            enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
            expect(enqueued_job.priority).to eq(23)
          end

          context 'when SecurityContext does not have a user guid' do
            let(:security_context) { double({ current_user_email: 'user-email', current_user_name: 'user-name', current_user: double({}) }) }

            before do
              stub_const('VCAP::CloudController::SecurityContext', security_context)
            end

            it 'does not change its delayed job\'s base priority' do
              TestConfig.config[:jobs][:priorities] = { 'droplet.delete': 20 }

              enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
              expect(enqueued_job.priority).to eq(20)
            end

            it 'uses nil for the user_guid' do
              TestConfig.config[:jobs][:priorities] = { 'droplet.delete': 20 }

              enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)

              job_record = VCAP::CloudController::PollableJobModel.find(delayed_job_guid: enqueued_job.guid)
              expect(job_record.user_guid).to be_nil
            end
          end
        end
      end

      context 'when dynamic job priorities are disabled' do
        context 'when there are several active jobs for the current user' do
          let(:security_context) { double({ current_user_email: 'user-email', current_user_name: 'user-name', current_user: double({ guid: 'user-guid' }) }) }
          let(:pollable_job) { PollableJobWrapper.new(job) }

          before do
            stub_const('VCAP::CloudController::SecurityContext', security_context)
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
          end

          it 'does not change its delayed job\'s base priority' do
            TestConfig.config[:jobs][:priorities] = { 'droplet.delete': 20 }

            enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
            expect(enqueued_job.priority).to eq(20)
          end
        end
      end

      context 'reusing a pollable job' do
        let!(:existing) { VCAP::CloudController::PollableJobModel.make }
        let(:pollable_job) { PollableJobWrapper.new(job, existing_guid: existing.guid) }

        it 'updates the existing database record with the new delayed job guid' do
          jobs_before_enqueue = VCAP::CloudController::PollableJobModel.all.length
          expect(jobs_before_enqueue).to eq(1)

          enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)

          jobs_after_enqueue = VCAP::CloudController::PollableJobModel.all.length
          expect(jobs_after_enqueue).to eq(1)

          job_record = VCAP::CloudController::PollableJobModel.find(delayed_job_guid: enqueued_job.guid)
          expect(job_record).not_to be_nil, "Expected to find PollableJobModel with delayed_job_guid '#{enqueued_job.guid}', but did not"
          expect(job_record.state).to eq('POLLING')
          expect(job_record.operation).to eq('droplet.delete')
          expect(job_record.resource_guid).to eq('fake')
          expect(job_record.resource_type).to eq('droplet')
          expect(job_record.cf_api_error).to be_nil
        end

        context 'when dynamic job priorities are enabled' do
          before do
            TestConfig.config[:jobs][:enable_dynamic_job_priorities] = true
          end

          context 'when there are several active jobs for the current user' do
            let(:security_context) { double({ current_user_email: 'user-email', current_user_name: 'user-name', current_user: double({ guid: 'user-guid' }) }) }

            before do
              stub_const('VCAP::CloudController::SecurityContext', security_context)
              VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
              VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
              VCAP::CloudController::Jobs::Enqueuer.new.enqueue(PollableJobWrapper.new(job))
            end

            it 'does not change its delayed job\'s base priority' do
              TestConfig.config[:jobs][:priorities] = { 'droplet.delete': 20 }

              enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
              expect(enqueued_job.priority).to eq(20)
            end
          end
        end

        context 'when the job defines its state' do
          before do
            job.define_singleton_method(:pollable_job_state) do
              'ABRACADABRA'
            end
          end

          it 'updates the existing job state accordingly' do
            enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
            job_record = VCAP::CloudController::PollableJobModel.find(delayed_job_guid: enqueued_job.guid)
            expect(job_record.state).to eq('ABRACADABRA')
          end
        end
      end

      context 'when the job fails' do
        before do
          allow_any_instance_of(VCAP::CloudController::Jobs::DeleteActionJob).
            to receive(:perform).and_raise(CloudController::Blobstore::BlobstoreError.new('some-error'))
          allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
        end

        context 'when there is an associated job model' do
          it 'marks the job model failed and records errors' do
            enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
            job_model = VCAP::CloudController::PollableJobModel.make(delayed_job_guid: enqueued_job.guid, state: 'PROCESSING')

            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            job_model.reload
            expect(job_model.state).to eq('FAILED')
            expect(job_model.cf_api_error).not_to be_nil

            api_error = YAML.safe_load(job_model.cf_api_error)['errors'].first
            expect(api_error['title']).to eql('CF-BlobstoreError')
            expect(api_error['code']).to be(150_007)
            expect(api_error['detail']).to eql('Failed to perform blobstore operation after three retries.')
          end
        end

        context 'when there is NOT an associated job model' do
          it 'does NOT choke' do
            VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)

            execute_all_jobs(expected_successes: 0, expected_failures: 1)
          end
        end
      end
    end

    describe 'warnings' do
      let(:broker) do
        VCAP::CloudController::ServiceBroker.create(
          name: 'test-broker',
          broker_url: 'http://example.org/broker-url',
          auth_username: 'username',
          auth_password: 'password'
        )
      end

      let(:user_audit_info) { instance_double(VCAP::CloudController::UserAuditInfo, { user_guid: Sham.guid }) }
      let(:job) { VCAP::CloudController::V3::SynchronizeBrokerCatalogJob.new(broker.guid, user_audit_info:) }

      before do
        allow_any_instance_of(VCAP::CloudController::V3::SynchronizeBrokerCatalogJob).
          to receive(:perform)

        allow_any_instance_of(VCAP::CloudController::V3::SynchronizeBrokerCatalogJob).
          to receive(:warnings).and_return(expected_warnings)
      end

      context 'when warnings were issued' do
        let(:expected_warnings) { [{ detail: 'warning 1' }, { detail: 'warning 2' }] }

        it 'records all warnings' do
          enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
          job_model = VCAP::CloudController::PollableJobModel.make(delayed_job_guid: enqueued_job.guid, state: 'PROCESSING')

          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          job_model.reload
          expect(job_model.state).to eq('COMPLETE')
          warnings = job_model.warnings
          expect(warnings.to_json).to include(expected_warnings[0][:detail], expected_warnings[1][:detail])
        end
      end

      context 'when warnings were not issued' do
        let(:expected_warnings) { nil }

        it 'has empty list of warnings' do
          enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new.enqueue(pollable_job)
          job_model = VCAP::CloudController::PollableJobModel.make(delayed_job_guid: enqueued_job.guid, state: 'PROCESSING')

          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          job_model.reload
          expect(job_model.state).to eq('COMPLETE')
          warnings = job_model.warnings
          expect(warnings.to_json).to eq('[]')
        end
      end
    end

    describe 'error' do
      let(:job) { double(job_name_in_configuration: 'my-job', max_attempts: 2, perform: nil, guid: '15') }
      let!(:actual_pollable_job) { VCAP::CloudController::PollableJobModel.create(delayed_job_guid: job.guid) }

      before do
        allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
      end

      context 'with a big backtrace' do
        it 'culls it down' do
          exception = BigException.new
          exception.set_backtrace(['1000 character backtrace: ' + ('x' * 974)] * 32)
          pollable_job.error(job, exception)
          expect(actual_pollable_job.reload.cf_api_error).not_to be_empty
          block = YAML.safe_load(actual_pollable_job.cf_api_error)
          errors = block['errors']
          expect(errors.size).to eq(1)
          error = errors[0]['test_mode_info']
          expect(error['detail']).to eq('VCAP::CloudController::Jobs::BigException')
          expect(error['backtrace'].size).to eq 8
        end
      end

      context 'with a big message' do
        # postgres complains with 15,826
        # mysql complains with 15,829, so test for failure at that point

        it 'squeezes just right one in' do
          expect do
            pollable_job.error(job, BigException.new(message: 'x' * 15_825))
          end.not_to raise_error
        end

        it 'gives up' do
          pg_error = /value too long for type character varying/
          mysql_error = /Data too long for column 'cf_api_error'/
          expect do
            pollable_job.error(job, BigException.new(message: 'x' * 15_829))
          end.to raise_error(::Sequel::DatabaseError, /#{pg_error}|#{mysql_error}/)
        end
      end
    end

    describe '#max_attempts' do
      it 'delegates to the handler' do
        expect(pollable_job.max_attempts).to eq(2)
      end
    end

    describe '#reschedule_at' do
      before do
        allow(job).to receive(:reschedule_at) do |time, attempts|
          time + attempts
        end
      end

      it 'defers to the inner job' do
        time = Time.now
        attempts = 5
        expect(pollable_job.reschedule_at(time, attempts)).to eq(job.reschedule_at(time, attempts))
      end
    end
  end
end
