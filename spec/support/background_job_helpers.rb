module BackgroundJobHelpers
  include VCAP::CloudController

  def execute_all_jobs(expected_successes:, expected_failures:, jobs_to_execute: 100)
    # SecurityContext is not available for worker threads in production, so we clear it
    # for testing jobs to avoid false positives
    saved_user = VCAP::CloudController::SecurityContext.current_user
    saved_token = VCAP::CloudController::SecurityContext.token
    saved_auth_token = VCAP::CloudController::SecurityContext.auth_token
    VCAP::CloudController::SecurityContext.clear

    successes, failures = Delayed::Worker.new.work_off(jobs_to_execute)
    failure_message = "Expected #{expected_successes} successful and #{expected_failures} failed jobs, got #{successes} successful and #{failures} failed jobs."
    fail_summaries = Delayed::Job.exclude(failed_at: nil).map { |j| "Handler: #{j.handler}, LastError: #{j.last_error}" }
    if fail_summaries.count > 0
      failure_message += " Failures: \n#{fail_summaries.join("\n")}"
    end
    expect([successes, failures]).to eq([expected_successes, expected_failures]), failure_message

    VCAP::CloudController::SecurityContext.set(saved_user, saved_token, saved_auth_token)
  end
end
