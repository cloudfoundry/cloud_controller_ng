require 'hashdiff'

RSpec::Matchers.define :be_a_response_like do |expected, problem_keys=[]|
  define_method :init_problem_keys do
    @problem_keys ||= problem_keys
  end

  define_method :bad_key! do |key|
    @problem_keys << key
  end

  define_method :truncate do |value, max_length|
    val = value.to_s
    if val.size > max_length - 3
      val = val[0...max_length] + '...'
    end
    val
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
    actual.each_key do |actual_key, actual_value|
      expect(expected).to have_key(actual_key)
    end
  end

  diffable

  summary = []
  exception = nil
  failure_message do |actual|
    begin
      diffs = HashDiff.best_diff(expected, actual)
      if diffs
        diffs.each do |comparator, key, expected_value, actual_value|
          case comparator
          when '-'
            summary << "- #{key}: #{truncate(expected_value, 80)}"
          when '+'
            summary << "+ #{key}: #{truncate(expected_value, 80)}"
          when '~'
            next if expected_value.is_a?(Regexp) && expected_value.match(actual_value) rescue false
            summary << "! #{key}:"
            if expected_value.is_a?(Regexp)
              expected_value = expected_value.inspect
            end
            summary << "  - #{truncate(expected_value, 80)}"
            summary << "  + #{truncate(actual_value, 80)}"
          end
        end
      end
    rescue => ex
      exception = "Error in hashdiff: #{ex} \n #{ex.backtrace[0..5]}"
    end

    result = []
    if summary.size > 0
      result << "Summary:\n#{summary.map { |s| '      ' + s }.join("\n")}\n"
    end
    if !!@problem_keys
      result << '' if result.size > 0
      result << "Bad keys: #{@problem_keys}"
    end
    if exception
      result << '' if result.size > 0
      result << 'Exception:'
      result << exception
    end
    result.join("\n")
  end
end
