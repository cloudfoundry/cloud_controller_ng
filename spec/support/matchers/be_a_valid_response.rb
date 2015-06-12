RSpec::Matchers.define :be_a_response_like do |expected|
  match do |actual|
    expected.each do |expected_key, expected_value|
      if expected_value.is_a?(Array)
        expected_value.each_with_index do |nested_expected_value, index|
          expect(actual[expected_key][index]).to be_a_response_like(nested_expected_value)
        end
      else
        expect(actual[expected_key]).to match(expected_value)
      end
    end

    # ensure there are not extra fields returned unexpectedly
    actual.each do |actual_key, actual_value|
      if actual_value.is_a?(Array)
        actual_value.each_with_index do |nested_actual_value, index|
          expect(expected[actual_key][index]).to be_a_response_like(nested_actual_value)
        end
      else
        expect(expected[actual_key]).to match(actual_value)
      end
    end
  end
end
