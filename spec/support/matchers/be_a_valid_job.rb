RSpec::Matchers.define :be_a_valid_job do
  problems = []
  match do |actual_job|
    unless actual_job.respond_to?(:max_attempts)
      problems << "max_attempts not implemented"
    end
    problems.empty?
  end

  failure_message_for_should do |actual_job|
    "Not a valid Job. Problems were:\n" + problems.join("\n")
  end

end
