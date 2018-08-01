RSpec::Matchers.define :be_a_response_like do |expected, problem_keys=[]|
  define_method :init_problem_keys do
    @problem_keys ||= problem_keys
  end

  define_method :bad_key! do |key|
    @problem_keys << key
  end

  match do |actual|
    init_problem_keys

    expected.each do |expected_key, expected_value|
      expect(actual).to have_key(expected_key)
      if expected_value.is_a?(Array)
        if expected_value.length != actual[expected_key].length
          bad_key!(expected_key)
          expect(expected_value.length).to eq(actual[expected_key].length)
        else
          expected_value.each_with_index do |nested_expected_value, index|
            if nested_expected_value.is_a?(Hash)
              expect(actual[expected_key][index]).to be_a_response_like(nested_expected_value, @problem_keys)
            else
              expect(actual[expected_key][index]).to eq(nested_expected_value)
            end
          end
        end
      elsif expected_value.is_a?(String)
        bad_key!(expected_key) unless expected_value == actual[expected_key]
        expect(actual[expected_key]).to eq(expected_value)
      else
        bad_key!(expected_key) unless values_match? expected_value, actual[expected_key]
        expect(actual[expected_key]).to match(expected_value)
      end
    end

    # ensure there are not extra fields returned unexpectedly
    actual.each do |actual_key, actual_value|
      expect(expected).to have_key(actual_key)
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
