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
  end
end
