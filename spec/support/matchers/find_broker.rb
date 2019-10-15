RSpec::Matchers.define :find_broker do |expected|
  match do
    method = expected.fetch(:method, :get)
    body = expected.fetch(:body, {})
    user = expected.fetch(:with, nil)
    public_send(method, "/v3/service_brokers/#{expected[:broker_guid]}", body, user)

    last_response.status == 200
  end

  failure_message do
    "expected broker with GUID '#{expected[:broker_guid]}' to be found"
  end

  failure_message_when_negated do
    "expected broker with GUID '#{expected[:broker_guid]}' to not be found"
  end
end
