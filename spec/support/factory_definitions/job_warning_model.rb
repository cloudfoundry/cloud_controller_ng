FactoryBot.define do
  factory :job_warning_model, class: 'VCAP::CloudController::JobWarningModel' do
    guid   { generate(:guid) }
    detail { 'job warning' }
    association :job, factory: :pollable_job_model
  end
end
