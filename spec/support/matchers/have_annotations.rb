RSpec::Matchers.define :have_annotations do |*expected|
  actual_annotations = []

  match do |actual|
    actual_annotations = actual.annotations.map do |annotation|
      {
        prefix: annotation.key_prefix,
        key: annotation.key_name,
        value: annotation.value,
      }
    end

    if expected.any?
      expected = expected.map do |annotation|
        {
          prefix: annotation.with_indifferent_access[:prefix],
          key: annotation.with_indifferent_access[:key],
          value: annotation.with_indifferent_access[:value],
        }
      end

      expect(actual_annotations).to match_array(expected)
    else # Situation: expect(thing).to have_annotations
      expect(actual_annotations).not_to be_empty
    end
  end

  failure_message do
    if expected.any?
      [
        "Annotations don't match!",
        "Expected #{expected}",
        "     got #{actual_annotations}",
      ].join("\n")
    else
      'Expected annotations but found none!'
    end
  end

  failure_message_when_negated do
    if expected.any?
      "Annotations unexpectedly match: got #{actual_annotations}"
    else
      "Expected no annotations but got #{actual_annotations}"
    end
  end
end
