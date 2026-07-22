# Asserts a RootJobMixin-based delete job runs the mixin guards before its own delete action (mixin
# behaviour itself is covered in root_job_mixin_spec). The host spec must define:
##   subject(:job)                 - the job instance under test
##   root_operation                - the root pollable operation string, e.g. 'app.delete'
##   resource_guid_for_job         - the guid used on the root pollable's resource_guid
##   expect_no_delete_attempt { }  - wraps a block, asserting the host action's delete is NOT invoked
##   destroy_resource              - removes the underlying resource (app/instance) from the db
RSpec.shared_examples 'a recursive delete root job' do
  let!(:root_pollable_job) do
    create(:pollable_job_model,
           state: VCAP::CloudController::PollableJobModel::PROCESSING_STATE,
           resource_guid: resource_guid_for_job,
           operation: root_operation)
  end

  def make_failed_sub_job(resource_guid: 'binding-guid')
    create(:pollable_job_model,
           root_job_guid: root_pollable_job.guid,
           state: VCAP::CloudController::PollableJobModel::FAILED_STATE,
           resource_type: 'service_credential_binding',
           resource_guid: resource_guid,
           cf_api_error: YAML.dump({ 'errors' => [{ 'detail' => 'unbind could not be completed: broker down' }] }))
  end

  context 'when a sub-job is still in flight' do
    let!(:pending_sub_job) do
      create(:pollable_job_model, root_job_guid: root_pollable_job.guid, state: VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
    end

    it 'defers: does not attempt the delete and does not finish' do
      expect_no_delete_attempt { job.perform }
      expect(job.finished).to be_falsey
    end

    it 'still defers when the resource is already gone (guard runs before the resource lookup)' do
      destroy_resource
      expect_no_delete_attempt { job.perform }
      expect(job.finished).to be_falsey
    end
  end

  context 'when a sub-job has failed' do
    let!(:failed_sub_job) { make_failed_sub_job }

    it 'surfaces the failure and does not attempt the delete' do
      expect_no_delete_attempt do
        expect { job.perform }.to raise_error(CloudController::Errors::CompoundError)
      end
    end
  end
end
