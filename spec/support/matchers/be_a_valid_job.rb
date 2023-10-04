RSpec::Matchers.define :be_a_valid_job do
  problems = []
  match do |actual_job|
    problems << 'max_attempts not implemented' unless actual_job.respond_to?(:max_attempts)
    problems.empty?
  end

  failure_message do |_actual_job|
    "Not a valid Job. Problems were:\n" + problems.join("\n")
  end
end
