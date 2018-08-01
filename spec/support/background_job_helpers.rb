module BackgroundJobHelpers
  include VCAP::CloudController

  def execute_all_jobs(expected_successes:, expected_failures:)
    successes, failures = Delayed::Worker.new.work_off
    expect([successes, failures]).to eq([expected_successes, expected_failures]),
      "expected #{expected_successes} successful and #{expected_failures} failed jobs, got #{successes} successful and #{failures} failed jobs"
  end
end
