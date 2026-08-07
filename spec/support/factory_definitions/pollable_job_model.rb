FactoryBot.define do
  factory :pollable_job_model, class: 'VCAP::CloudController::PollableJobModel' do
    guid { generate(:guid) }
    operation { 'app.job' }
    state { 'COMPLETE' }
    resource_guid { generate(:guid) }
    resource_type { 'app' }

    # A failed sub-job carrying a broker error detail, e.g. create(:pollable_job_model, :failed, detail: 'broker down')
    trait :failed do
      transient do
        detail { nil }
      end

      state { 'FAILED' }
      resource_type { 'service_credential_binding' }
      cf_api_error { detail && YAML.dump({ 'errors' => [{ 'detail' => detail }] }) }
    end
  end
end
