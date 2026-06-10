FactoryBot.define do
  factory :pollable_job_model, class: 'VCAP::CloudController::PollableJobModel' do
    guid { generate(:guid) }
    operation { 'app.job' }
    state { 'COMPLETE' }
    resource_guid { generate(:guid) }
    resource_type { 'app' }
  end
end
