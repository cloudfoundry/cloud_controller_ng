module VCAP::CloudController
  class LabelHelpers
    KEY_SEPARATOR = '/'.freeze
    REQUIREMENT_SPLITTER = /(?:\(.*?\)|[^,])+/

    IN_PATTERN = /(?<key>.*) in \((?<values>.*)\)$/                                 # foo in (bar,baz)
    NOT_IN_PATTERN = /(?<key>.*) notin \((?<values>.*)\)$/                          # funky notin (uptown,downtown)
    EQUALS_PATTERN = %r{^(?!=)(?<key>[\w\-\.\_\/]*)(=|==)(?<values>[\w\-\.\_]*)$}   # foo=bar or foo==bar
    NOT_EQUALS_PATTERN = %r{(?<key>[\w\-\.\_\/]*)(!=)(?<values>[\w\-\.\_]*)$}       # foo!=bar
    EXISTENCE_PATTERN = /^(?!!)(?<key>.*)$(?<values>)/                              # foo
    NON_EXISTENCE_PATTERN = /!(?<key>.*)$(?<values>)/                               # !foo

    REQUIREMENT_OPERATOR_PAIRS = [
      { pattern: IN_PATTERN, operator: :in },
      { pattern: NOT_IN_PATTERN, operator: :notin },
      { pattern: EQUALS_PATTERN, operator: :equal },
      { pattern: NOT_EQUALS_PATTERN, operator: :not_equal },
      { pattern: EXISTENCE_PATTERN, operator: :exists }, # foo
      { pattern: NON_EXISTENCE_PATTERN, operator: :not_exists },
    ].freeze

    class << self
      def extract_prefix(label_key)
        return [nil, label_key] unless label_key.include?(KEY_SEPARATOR)

        prefix, name = label_key.split(KEY_SEPARATOR)
        name ||= ''
        [prefix, name]
      end
    end
  end
end
