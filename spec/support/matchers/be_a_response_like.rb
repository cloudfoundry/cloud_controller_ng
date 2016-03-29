RSpec::Matchers.define :be_a_response_like do |expected|
  define_method :bad_key! do |key|
    @problem_keys ||= []
    @problem_keys << key
  end

  match do |actual|
    expected.each do |expected_key, expected_value|
      expect(actual).to have_key(expected_key)
      if expected_value.is_a?(Array)
        expected_value.each_with_index do |nested_expected_value, index|
          expect(actual[expected_key][index]).to be_a_response_like(nested_expected_value)
        end
      else
        bad_key!(expected_key) unless values_match? expected_value, actual[expected_key]
        expect(actual[expected_key]).to match(expected_value)
      end
    end

    # ensure there are not extra fields returned unexpectedly
    actual.each do |actual_key, actual_value|
      expect(expected).to have_key(actual_key)
      if actual_value.is_a?(Array)
        actual_value.each_with_index do |nested_actual_value, index|
          expect(expected[actual_key][index]).to be_a_response_like(nested_actual_value)
        end
      else
        bad_key!(actual_key) unless values_match? expected[actual_key], actual_value
        expect(expected[actual_key]).to match(actual_value)
      end
    end
  end

  diffable

  failure_message do |actual|
    bad_keys_info = (!!@problem_keys ? "Bad keys: #{@problem_keys}" : '')

    <<-HEREDOC
      expected: #{expected}
      got:      #{actual}
      #{bad_keys_info}
    HEREDOC
  end
end
