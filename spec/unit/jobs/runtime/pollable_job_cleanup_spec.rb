require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PollableJobCleanup, job_context: :worker do
      let(:cutoff_age_in_days) { 30 }
      subject(:job) { PollableJobCleanup.new(cutoff_age_in_days) }
      let!(:old_job) { PollableJobModel.create(created_at: (cutoff_age_in_days + 1).days.ago) }
      let!(:old_warning) { JobWarningModel.create(job: old_job, created_at: old_job.created_at, detail: 'some warning') }
      let!(:new_job) { PollableJobModel.create(created_at: (cutoff_age_in_days - 1).day.ago) }
      let!(:new_warning) { JobWarningModel.create(job: new_job, created_at: new_job.created_at, detail: 'some warning') }

      it { is_expected.to be_a_valid_job }

      it 'removes pollable jobs that are older than the specified cutoff age' do
        job.perform
        expect(PollableJobModel.find(guid: old_job.guid)).to be_nil
      end

      it 'leaves the pollable jobs that are younger than the specified cutoff age' do
        job.perform
        expect(PollableJobModel.find(guid: new_job.guid)).to eq(new_job)
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:pollable_job_cleanup)
      end

      it 'also deletes associated warnings' do
        job.perform
        expect(JobWarningModel.find(id: old_warning.id)).to be_nil
        expect(JobWarningModel.find(id: new_warning.id)).to eq(new_warning)
      end
    end
  end
end
