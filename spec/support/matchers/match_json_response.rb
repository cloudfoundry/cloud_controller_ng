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
      diffs = Hashdiff.best_diff(expected.deep_symbolize_keys, actual)
      if diffs
        diffs.each do |comparator, key, expected_value, actual_value|
          case comparator
          when '-'
            summary << "- #{key}: #{expected_value}"
          when '+'
            summary << "+ #{key}: #{expected_value}"
          when '~'
            begin
              next if expected_value.is_a?(Regexp) && expected_value.match(actual_value)
            rescue StandardError
              false
            end
            begin
              next if expected_value.matches?(actual_value)
            rescue StandardError
              false
            end

            summary << "! #{key}:"
            expected_value = expected_value.inspect if expected_value.is_a?(Regexp)

            if expected_value.respond_to?(:failure_message)
              expected_value.failure_message.split("\n").each { |l| summary << l }
            else
              summary << "  - #{expected_value}"
              summary << "  + #{actual_value}"
            end
          end
        end
      end
    rescue StandardError => e
      exception = "Error in hashdiff: #{e} \n #{e.backtrace[0..5].join("\n")}"
    end

    result = []
    unless summary.empty?
      result << "Expected:\n#{Oj.dump(expected)}\nto equal:\n#{Oj.dump(actual)}\n"
      result << "Summary:\n#{summary.map { |s| '      ' + s }.join("\n")}\n"
    end
    if exception
      result << '' unless result.empty?
      result << 'Exception:'
      result << exception
    end
    result.join("\n")
  end
end
