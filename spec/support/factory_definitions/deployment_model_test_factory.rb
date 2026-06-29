FactoryBot.define do
  factory :deployment_model_test_factory, class: 'VCAP::CloudController::DeploymentModel' do
    skip_create

    transient do
      app { nil }
      droplet { nil }
      previous_droplet { nil }
      deploying_web_process { nil }
      last_healthy_at { nil }
      status_updated_at { nil }
      state { nil }
      status_value { nil }
      status_reason { nil }
      web_instances { nil }
      memory_in_mb { nil }
      disk_in_mb { nil }
      log_rate_limit_in_bytes_per_second { nil }
      strategy { nil }
      max_in_flight { nil }
      canary_steps { nil }
      original_web_process_instance_count { nil }
      error { nil }
    end

    initialize_with do
      attrs = {}
      attrs[:app] = app if app
      attrs[:droplet] = droplet if droplet
      attrs[:previous_droplet] = previous_droplet if previous_droplet
      attrs[:deploying_web_process] = deploying_web_process if deploying_web_process
      attrs[:last_healthy_at] = last_healthy_at if last_healthy_at
      attrs[:status_updated_at] = status_updated_at if status_updated_at
      attrs[:state] = state if state
      attrs[:status_value] = status_value if status_value
      attrs[:status_reason] = status_reason if status_reason
      attrs[:web_instances] = web_instances unless web_instances.nil?
      attrs[:memory_in_mb] = memory_in_mb unless memory_in_mb.nil?
      attrs[:disk_in_mb] = disk_in_mb unless disk_in_mb.nil?
      attrs[:log_rate_limit_in_bytes_per_second] = log_rate_limit_in_bytes_per_second unless log_rate_limit_in_bytes_per_second.nil?
      attrs[:strategy] = strategy if strategy
      attrs[:max_in_flight] = max_in_flight unless max_in_flight.nil?
      attrs[:canary_steps] = canary_steps if canary_steps
      attrs[:original_web_process_instance_count] = original_web_process_instance_count unless original_web_process_instance_count.nil?
      attrs[:error] = error if error
      VCAP::CloudController::DeploymentModelTestFactory.make(attrs)
    end
  end
end
