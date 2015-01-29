RSpec::Matchers.define :be_a_fully_wrapped_job_of do |expected_job_class|
  match do |actual_job|
    next_job = actual_job.payload_object
    return false unless next_job.is_a? VCAP::CloudController::Jobs::ExceptionCatchingJob

    next_job = next_job.handler
    return false unless next_job.is_a? VCAP::CloudController::Jobs::RequestJob

    next_job = next_job.job
    return false unless next_job.is_a? VCAP::CloudController::Jobs::TimeoutJob

    base_job = next_job.job
    base_job.is_a? expected_job_class
  end
end
