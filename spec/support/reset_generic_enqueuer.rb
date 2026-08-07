# Reset the GenericEnqueuer thread-local after every example so a root_job_guid can't leak across parallel-worker specs.
RSpec.configure do |config|
  config.after do
    VCAP::CloudController::Jobs::GenericEnqueuer.reset!
  end
end
