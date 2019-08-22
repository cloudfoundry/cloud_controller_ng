RSpec::Matchers.define :find_broker do |expected|
  match do
    get("/v3/service_brokers/#{expected[:broker_guid]}", {}, expected[:with] || nil)

    last_response.status == 200
  end

  failure_message do
    "expected broker with GUID '#{expected[:broker_guid]}' to be found"
  end

  failure_message_when_negated do
    "expected broker with GUID '#{expected[:broker_guid]}' to not be found"
  end
end
