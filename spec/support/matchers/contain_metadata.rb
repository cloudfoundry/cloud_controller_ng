RSpec::Matchers.define :contain_metadata do |expected|
  labels_match = false
  annotations_match = false
  actual_labels = []
  actual_annotations = []
  expected_labels = []
  expected_annotations = []

  match do |actual|
    actual_labels = actual.labels.map { |label| { key: label.key_name, value: label.value } }
    actual_annotations = actual.annotations.map { |a| { key: a.key, value: a.value } }

    expected_labels = expected.dig(:metadata, :labels).map { |k, v| { key: k.to_s, value: v } }
    expected_annotations = expected.dig(:metadata, :annotations).map { |k, v| { key: k.to_s, value: v } }

    labels_match = true if hash_equal?(actual_labels, expected_labels)
    annotations_match = true if hash_equal?(actual_annotations, expected_annotations)

    labels_match && annotations_match
  end

  failure_message do
    error_message = []
    error_message << "Labels don't match: Expected #{expected_labels} got #{actual_labels}" unless labels_match
    error_message << "Annotations don't match: Expected #{expected_annotations} got #{actual_annotations}" unless annotations_match

    error_message.join("\n")
  end

  def hash_equal?(hash1, hash2)
    array1 = hash1.to_a
    array2 = hash2.to_a
    (array1 - array2 | array2 - array1) == []
  end
end
