module VCAP::CloudController
  class MetadataHelpers
    KEY_SEPARATOR = '/'.freeze
    REQUIREMENT_SPLITTER = /(?:\(.*?\)|[^,])+/
    KEY_CHARACTERS = %r{[\w\-\.\_\/]+}

    IN_PATTERN = /\A(?<key>.*?) in \((?<values>.*)\)\z/                     # foo in (bar,baz)
    NOT_IN_PATTERN = /\A(?<key>.*?) notin \((?<values>.*)\)\z/              # funky notin (uptown,downtown)
    EQUAL_PATTERN = /\A(?<key>#{KEY_CHARACTERS})(==?)(?<values>.*)\z/       # foo=bar or foo==bar
    NOT_EQUAL_PATTERN = /\A(?<key>#{KEY_CHARACTERS})(!=)(?<values>.*)\z/    # foo!=bar
    EXISTS_PATTERN = /^\A(?<key>#{KEY_CHARACTERS})(?<values>)\z/            # foo
    NOT_EXISTS_PATTERN = /\A!(?<key>#{KEY_CHARACTERS})(?<values>)\z/        # !foo

    REQUIREMENT_OPERATOR_PAIRS = [
      { pattern: IN_PATTERN, operator: :in },
      { pattern: NOT_IN_PATTERN, operator: :notin },
      { pattern: EQUAL_PATTERN, operator: :equal },
      { pattern: NOT_EQUAL_PATTERN, operator: :not_equal },
      { pattern: EXISTS_PATTERN, operator: :exists }, # foo
      { pattern: NOT_EXISTS_PATTERN, operator: :not_exists },
    ].freeze

    class << self
      def extract_prefix(metadata_key)
        return [nil, metadata_key] unless metadata_key.include?(KEY_SEPARATOR)

        prefix, name = metadata_key.split(KEY_SEPARATOR)
        name ||= ''
        [prefix, name]
      end
    end
  end
end
