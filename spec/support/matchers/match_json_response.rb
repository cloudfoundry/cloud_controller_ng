require 'hashdiff'

RSpec::Matchers.define :match_json_response do |expected|
  match do |actual|
    actual = actual.deep_symbolize_keys
    expect(actual).to match(expected.deep_symbolize_keys)
  end

  summary = []
  exception = nil
  failure_message do |actual|
    actual = actual.deep_symbolize_keys

    begin
      diffs = HashDiff.best_diff(expected.deep_symbolize_keys, actual)
      if diffs
        diffs.each do |comparator, key, expected_value, actual_value|
          case comparator
          when '-'
            summary << "- #{key}: #{expected_value}"
          when '+'
            summary << "+ #{key}: #{expected_value}"
          when '~'
            next if expected_value.is_a?(Regexp) && expected_value.match(actual_value) rescue false
            next if expected_value.matches?(actual_value) rescue false

            summary << "! #{key}:"
            if expected_value.is_a?(Regexp)
              expected_value = expected_value.inspect
            end

            if expected_value.respond_to?(:failure_message)
              expected_value.failure_message.split("\n").each { |l| summary << l }
            else
              summary << "  - #{expected_value}"
              summary << "  + #{actual_value}"
            end
          end
        end
      end
    rescue => ex
      exception = "Error in hashdiff: #{ex} \n #{ex.backtrace[0..5].join("\n")}"
    end

    result = []
    if !summary.empty?
      result << "Expected:\n#{JSON.pretty_generate(expected)}\nto equal:\n#{JSON.pretty_generate(actual)}\n"
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
