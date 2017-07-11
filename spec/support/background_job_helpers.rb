module BackgroundJobHelpers
  include VCAP::CloudController

  def execute_all_jobs(expected_successes:, expected_failures:)
    successes, failures = Delayed::Worker.new.work_off
    failure_message = "Expected #{expected_successes} successful and #{expected_failures} failed jobs, got #{successes} successful and #{failures} failed jobs."
    if failures > 0
      fail_summaries = Delayed::Job.exclude(failed_at: nil).map { |j| "Handler: #{j.handler}, LastError: #{j.last_error}" }
      failure_message += " Failures: \n#{fail_summaries.join("\n")}"
    end
    expect([successes, failures]).to eq([expected_successes, expected_failures]), failure_message
  end
end
