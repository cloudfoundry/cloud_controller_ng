module BackgroundJobHelpers
  include VCAP::CloudController

  def execute_all_jobs
    successes, failures = Delayed::Worker.new.work_off
    expect([successes, failures]).to eq([1, 0]), 'delayed job failed'
  end
end
