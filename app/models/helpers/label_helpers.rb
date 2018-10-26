module VCAP::CloudController
  class LabelHelpers
    KEY_SEPARATOR = '/'.freeze
    REQUIREMENT_SPLITTER = /(?:\(.*?\)|[^,])+/
    IN_PATTERN = /(?<key>.*) in \((?<values>.*)\)$/
    NOT_IN_PATTERN = /(?<key>.*) notin \((?<values>.*)\)$/
    EQUALS_PATTERN = %r{^(?!=)(?<key>[\w\-\.\_\/]*)(=|==)(?<values>[\w\-\.\_]*)$}
    NOT_EQUALS_PATTERN = %r{(?<key>[\w\-\.\_\/]*)(!=)(?<values>[\w\-\.\_]*)$}
    REQUIREMENT_OPERATOR_PAIRS = [
      { pattern: IN_PATTERN, operator: :in }, # foo in (bar,baz)
      { pattern: NOT_IN_PATTERN, operator: :notin }, # funky notin (uptown,downtown)
      { pattern: EQUALS_PATTERN, operator: :equal }, # foo==bar
      { pattern: NOT_EQUALS_PATTERN, operator: :not_equal }, # foo!=bar
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
