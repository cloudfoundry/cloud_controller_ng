require 'hashdiff'

RSpec::Matchers.define :be_a_response_like do |expected, problem_keys=[]|
  define_method :init_problem_keys do
    @problem_keys ||= problem_keys # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  define_method :bad_key! do |key|
    @problem_keys << key
  end

  define_method :truncate do |value, max_length|
    val = value.to_s
    val = val[0...max_length] + '...' if val.size > max_length - 3
    val
  end

  match do |actual|
    init_problem_keys

    expected.each do |expected_key, expected_value|
      expect(actual).to have_key(expected_key)
      if expected_value.is_a?(Array)
        if expected_value.length == actual[expected_key].length
          expected_value.each_with_index do |nested_expected_value, index|
            if nested_expected_value.is_a?(Hash)
              expect(actual[expected_key][index]).to be_a_response_like(nested_expected_value, @problem_keys)
            else
              expect(actual[expected_key][index]).to eq(nested_expected_value)
            end
          end
        else
          bad_key!(expected_key)
          expect(expected_value.length).to eq(actual[expected_key].length)
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
    actual.each_key do |actual_key, _actual_value|
      expect(expected).to have_key(actual_key)
    end
  end

  diffable

  summary = []
  exception = nil
  failure_message do |actual|
    begin
      diffs = Hashdiff.best_diff(expected, actual)
      if diffs
        diffs.each do |comparator, key, expected_value, actual_value|
          case comparator
          when '-'
            summary << "- #{key}: #{truncate(expected_value, 80)}"
          when '+'
            summary << "+ #{key}: #{truncate(expected_value, 80)}"
          when '~'
            begin
              next if expected_value.is_a?(Regexp) && expected_value.match(actual_value)
            rescue StandardError
              false
            end
            summary << "! #{key}:"
            expected_value = expected_value.inspect if expected_value.is_a?(Regexp)
            summary << "  - #{truncate(expected_value, 80)}"
            summary << "  + #{truncate(actual_value, 80)}"
          end
        end
      end
    rescue StandardError => e
      exception = "Error in hashdiff: #{e} \n #{e.backtrace[0..5]}"
    end

    result = []
    result << "Summary:\n#{summary.map { |s| '      ' + s }.join("\n")}\n" unless summary.empty?
    if !!@problem_keys
      result << '' unless result.empty?
      result << "Bad keys: #{@problem_keys}"
    end
    if exception
      result << '' unless result.empty?
      result << 'Exception:'
      result << exception
    end
    result.join("\n")
  end
end
