require 'hashdiff'

RSpec::Matchers.define :match_json_response do |expected|
  define_method :truncate do |value, max_length|
    val = value
    if val.size > max_length - 3
      val = val[0...max_length] + '...'
    end
    val
  end

  match do |actual|
    actual = actual.deep_symbolize_keys
    expect(actual).to match(expected)
  end

  summary = []
  exception = nil
  failure_message do |actual|
    actual = actual.deep_symbolize_keys

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
    if !summary.empty?
      result << "Summary:\n#{summary.map { |s| '      ' + s }.join("\n")}\n"
    end
    if exception
      result << '' if !result.empty?
      result << 'Exception:'
      result << exception
    end
    result.join("\n")
  end
end
