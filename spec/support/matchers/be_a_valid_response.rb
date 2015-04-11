RSpec::Matchers.define :be_a_response_like do |expected_response|
  diff = []

  match do |actual_response|
    expect(actual_response['pagination']).to eq(expected_response['pagination'])

    if actual_response['resources']
      actual_response['resources'].each_with_index do |actual_resource, i|
        match_time(actual_resource)

        expect(actual_resource).to include(expected_response['resources'][i])
        #   resource_diff = nil
        #   expected_response['resources'][i].to_a.each do |item|
        #      resource_diff = actual_resource.to_a - item
        #   end
        #   diff << resource_diff
        # end
      end
    else
      match_time(actual_response)
      expect(actual_response).to include(expected_response)
    end
  end

  failure_message do |actual_response|
    "DGAF"
  end
end

private

def match_time(model)
  iso8601_regex = /^([\+-]?\d{4}(?!\d{2}\b))((-?)((0[1-9]|1[0-2])(\3([12]\d|0[1-9]|3[01]))?|W([0-4]\d|5[0-2])(-?[1-7])?|(00[1-9]|0[1-9]\d|[12]\d{2}|3([0-5]\d|6[1-6])))([T\s]((([01]\d|2[0-3])((:?)[0-5]\d)?|24\:?00)([\.,]\d+(?!:))?)?(\17[0-5]\d([\.,]\d+)?)?([zZ]|([\+-])([01]\d|2[0-3]):?([0-5]\d)?)?)?)?$/

  expect(model['created_at']).to match(iso8601_regex)
  expect(model['updated_at']).to match(iso8601_regex) if model['updated_at']
end
