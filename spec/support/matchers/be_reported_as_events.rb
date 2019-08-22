RSpec::Matchers.define :be_reported_as_events do
  events = []
  match do |expected_events|
    events = VCAP::CloudController::Event.all.sort_by(&:type).map { |e| { type: e.type, actor: e.actor_name } }
    events == expected_events
  end

  failure_message do
    "Expected events were not reported. Events reported: #{events}"
  end
end
