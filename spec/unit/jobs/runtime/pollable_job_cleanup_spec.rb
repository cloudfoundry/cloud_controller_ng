require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PollableJobCleanup, job_context: :worker do
      subject(:job) { PollableJobCleanup.new }
      let!(:old_job) { PollableJobModel.create(created_at: 91.days.ago) }
      let!(:new_job) { PollableJobModel.create(created_at: 1.days.ago) }

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
    end
  end
end
