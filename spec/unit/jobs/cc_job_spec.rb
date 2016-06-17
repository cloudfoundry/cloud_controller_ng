require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe CCJob do
      describe '#reschedule_at' do
        it 'uses the default from Delayed::Job' do
          time = Time.now
          attempts = 5
          job = CCJob.new
          expect(job.reschedule_at(time, attempts)).to eq(time + (attempts**4) + 5)
        end
      end
    end
  end
end
