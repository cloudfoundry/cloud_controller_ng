RSpec::Matchers.define :match_broker do |expected|
  problems = []

  match do |actual|
    problems << "Expected #{actual['url']} to be equal to #{expected.broker_url}" unless actual['url'] == expected.broker_url
    problems << "Expected #{actual['created_at']} to be equal to #{expected.created_at.iso8601}" unless actual['created_at'] == expected.created_at.iso8601
    problems << "Expected #{actual['updated_at']} to be equal to #{expected.updated_at.iso8601}" unless actual['updated_at'] == expected.updated_at.iso8601
    problems << "Expected broker object to have key 'links'" if actual['links'].nil?
    problems << "Expected broker.links to have key 'self'" if actual['links']['self'].nil?
    unless actual['links']['self']['href'].include?("/v3/service_brokers/#{expected.guid}")
      problems << "Expected #{actual['links']['self']['href']} to include '/v3/service_brokers/#{expected.guid}'"
    end

    if expected.space.nil?
      problems << 'Expected broker relationships to be empty' unless actual['relationships'].empty?
      # problems << "Expected #{actual['links']}).not_to have_key('space')
      problems << "Expected broker.links to not have key 'space'" unless actual['links']['space'].nil?
    else
      problems << 'Expected broker relationships to not be empty' if actual['relationships'].empty?
      problems << "Expected broker.links to have key 'space'" if actual['links']['space'].nil?
      problems << "Expected broker.relationships.space to have key 'data'" if actual['relationships']['space']['data'].nil?
      unless actual['relationships']['space']['data']['guid'] == expected.space.guid
        problems << "Expected #{actual['relationships']['space']['data']['guid']} to be equal to #{expected.space.guid}"
      end
      unless actual['links']['space']['href'].include?("/v3/spaces/#{expected.space.guid}")
        problems << "Expected #{actual['links']['space']['href']} to include '/v3/spaces/#{expected.space.guid}'"
      end
    end

    expected_availability = expected.service_broker_state&.state == VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE
    problems << "Expected broker availability #{actual['available']} to be equal to #{expected_availability}" unless actual['available'] == expected_availability
    expected_status = {
      VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE => 'available',
      VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING => 'synchronization in progress',
      VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED => 'synchronization failed'
    }.fetch(expected.service_broker_state&.state, 'unknown')
    problems << "Expected broker status #{actual['status']} to be equal to #{expected_status}" unless actual['status'] == expected_status

    problems.empty?
  end

  failure_message do |actual_event|
    "Expect brokers to match, but it did not. Problems were:\n" + problems.join("\n")
  end
end
