RSpec::Matchers.define :have_labels do |*expected|
  actual_labels = []

  match do |actual|
    actual_labels = actual.labels.map do |label|
      {
        prefix: label.key_prefix,
        key: label.key_name,
        value: label.value,
      }
    end

    if expected.any?
      expected = expected.map do |label|
        {
          prefix: label.with_indifferent_access[:prefix],
          key: label.with_indifferent_access[:key],
          value: label.with_indifferent_access[:value],
        }
      end

      expect(actual_labels).to match_array(expected)
    else # Situation: expect(thing).to have_labels
      expect(actual_labels).not_to be_empty
    end
  end

  failure_message do
    if expected.any?
      [
        "Labels don't match!",
        "Expected #{expected}",
        "     got #{actual_labels}",
      ].join("\n")
    else
      'Expected labels but found none!'
    end
  end

  failure_message_when_negated do
    if expected.any?
      "Labels unexpectedly match: got #{actual_labels}"
    else
      "Expected no labels but got #{actual_labels}"
    end
  end
end
