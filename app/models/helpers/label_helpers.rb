module VCAP::CloudController
  class LabelHelpers
    KEY_SEPARATOR = '/'.freeze
    REQUIREMENT_SPLITTER = /(?:\(.*?\)|[^,])+/
    REQUIREMENT_OPERATOR_PAIRS = [
      { pattern: /(?<key>.*) in \((?<values>.*)\)$/, operator: :in }, # foo in (bar,baz)
      { pattern: /(?<key>.*) notin \((?<values>.*)\)$/, operator: :notin }, # funky notin (uptown,downtown)
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
