require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PollableJobModel do
    describe('.find_by_delayed_job') do
      let(:delayed_job) { Delayed::Backend::Sequel::Job.create }
      let!(:pollable_job) { PollableJobModel.create(state: 'PROCESSING', delayed_job_guid: delayed_job.guid) }

      it 'returns the PollableJobModel for the given DelayedJob' do
        result = PollableJobModel.find_by_delayed_job(delayed_job)
        expect(result).to be_present
        expect(result).to eq(pollable_job)
      end
    end

    describe('.find_by_delayed_job_guid') do
      let(:delayed_job) { Delayed::Backend::Sequel::Job.create }
      let!(:pollable_job) { PollableJobModel.create(state: 'PROCESSING', delayed_job_guid: delayed_job.guid) }

      it 'returns the PollableJobModel for the given DelayedJob' do
        result = PollableJobModel.find_by_delayed_job_guid(delayed_job.guid)
        expect(result).to be_present
        expect(result).to eq(pollable_job)
      end
    end

    describe '#complete?' do
      context 'when the state is complete' do
        let(:job) { PollableJobModel.make(state: 'COMPLETE') }

        it 'returns true' do
          expect(job.complete?).to be(true)
        end
      end

      context 'when the state is not complete' do
        let(:failed_job) { PollableJobModel.make(state: 'FAILED') }
        let(:processing_job) { PollableJobModel.make(state: 'PROCESSING') }

        it 'returns false' do
          expect(failed_job.complete?).to be(false)
          expect(processing_job.complete?).to be(false)
        end
      end
    end

    describe '#resource_exists?' do
      it 'returns true if the resource exists' do
        app = AppModel.make
        job = PollableJobModel.make(resource_type: 'app', resource_guid: app.guid)
        expect(job.resource_exists?).to be(true)
      end

      it 'returns false if the resource does NOT exist' do
        job = PollableJobModel.make(resource_type: 'app', resource_guid: 'not-a-real-guid')
        expect(job.resource_exists?).to be(false)
      end

      it 'returns false if the resource type is empty' do
        job = PollableJobModel.make(resource_type: '', resource_guid: '')
        expect(job.resource_exists?).to be(false)
      end

      context 'when the resource is a special case' do
        it 'returns true if the resource exists' do
          organization_quota = QuotaDefinition.make
          job = PollableJobModel.make(resource_type: 'organization_quota', resource_guid: organization_quota.
            guid)
          expect(job.resource_exists?).to be(true)
        end

        it 'returns false if the resource does NOT exist' do
          job = PollableJobModel.make(resource_type: 'organization_quota', resource_guid: 'not-a-real-guid')
          expect(job.resource_exists?).to be(false)
        end

        it 'returns true if the resource exists' do
          role = OrganizationManager.make
          job = PollableJobModel.make(resource_type: 'role', resource_guid: role.guid)
          expect(job.resource_exists?).to be(true)
        end

        it 'returns false if the resource does NOT exist' do
          job = PollableJobModel.make(resource_type: 'role', resource_guid: 'not-a-real-guid')
          expect(job.resource_exists?).to be(false)
        end

        it 'returns true if the route binding resource exists' do
          route_binding = RouteBinding.make
          job = PollableJobModel.make(resource_type: 'service_route_binding', resource_guid: route_binding.guid)
          expect(job.resource_exists?).to be(true)
        end

        it 'returns false if the route binding resource does NOT exist' do
          job = PollableJobModel.make(resource_type: 'service_route_binding', resource_guid: 'not-a-real-guid')
          expect(job.resource_exists?).to be(false)
        end

        it 'returns true if the service binding resource exists' do
          binding = ServiceBinding.make
          job = PollableJobModel.make(resource_type: 'service_credential_binding', resource_guid: binding.guid)
          expect(job.resource_exists?).to be(true)
        end

        it 'returns true if the service key resource exists' do
          binding = ServiceKey.make
          job = PollableJobModel.make(resource_type: 'service_credential_binding', resource_guid: binding.guid)
          expect(job.resource_exists?).to be(true)
        end

        it 'returns false if the service credential binding resource does NOT exist' do
          job = PollableJobModel.make(resource_type: 'service_credential_binding', resource_guid: 'not-a-real-guid')
          expect(job.resource_exists?).to be(false)
        end
      end
    end

    describe '#warnings' do
      it 'returns the warnings for the job' do
        job = PollableJobModel.make
        warnings = []
        warnings << JobWarningModel.make(job: job, detail: 'something is wrong')
        warnings << JobWarningModel.make(job: job, detail: 'something is really wrong')

        expect(job.warnings.size).to eq(2)
        expect(job.warnings).to include(*warnings)
      end

      it 'deletes the warnings when the job is deleted' do
        job = PollableJobModel.make
        JobWarningModel.make(job: job, detail: 'something is wrong')
        JobWarningModel.make(job: job, detail: 'something is really wrong')

        job.destroy

        expect(PollableJobModel.all).to be_empty
        expect(JobWarningModel.all).to be_empty
      end
    end
  end
end
