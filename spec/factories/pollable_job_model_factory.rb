require 'models/runtime/pollable_job_model'

FactoryBot.define do
  factory :pollable_job, class: VCAP::CloudController::PollableJobModel do
    guid
    operation { 'app.job' }
    state { 'COMPLETE' }
    resource_guid { generate(:guid) }
    resource_type { 'app' }
  end
end
