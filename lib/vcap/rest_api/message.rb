require 'vcap/json_message'

module VCAP
  module RestAPI
    class Message < JsonMessage
      class UrlDecorator < SimpleDelegator
        def inspect
          'String /URL_REGEX/'
        end

        alias_method :to_s, :inspect
        def default_error_message
          'must be a valid URL'
        end
      end

      class HttpsUrlDecorator < SimpleDelegator
        def inspect
          'String /HTTPS_URL_REGEX/'
        end

        alias_method :to_s, :inspect
        def default_error_message
          'must be a valid HTTPS URL'
        end
      end

      class EmailDecorator < SimpleDelegator
        def inspect
          'String /EMAIL_REGEX/'
        end

        alias_method :to_s, :inspect
        def default_error_message
          'must be a valid email'
        end
      end

      class GitUrlDecorator < SimpleDelegator
        def inspect
          'String /GIT_URL_REGEX/'
        end

        alias_method :to_s, :inspect

        def default_error_message
          'must be a valid git URL'
        end
      end
      # The schema validator used by class `JsonMessage` calls the `inspect`
      # method on the regexp object to get a description of the regex. We tweak
      # the regexp object so that the `inspect` method generates a readable
      # description for us through `VCAP::RestAPI::Message#schema_doc` method.
      def self.schema_doc(schema)
        schema.deparse
      end

      URL = UrlDecorator.new(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
      HTTPS_URL = HttpsUrlDecorator.new(URI::DEFAULT_PARSER.make_regexp('https'))
      QTEXT = '[^\\x0d\\x22\\x5c\\x80-\\xff]'.freeze
      DTEXT = '[^\\x0d\\x5b-\\x5d\\x80-\\xff]'.freeze
      ATOM = '[^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-' \
             '\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+'.freeze
      QUOTED_PAIR = '\\x5c[\\x00-\\x7f]'.freeze
      DOMAIN_LITERAL = "\\x5b(?:#{DTEXT}|#{QUOTED_PAIR})*\\x5d".freeze
      QUOTED_STRING = "\\x22(?:#{QTEXT}|#{QUOTED_PAIR})*\\x22".freeze
      DOMAIN_REF = ATOM
      SUB_DOMAIN = "(?:#{DOMAIN_REF}|#{DOMAIN_LITERAL})".freeze
      WORD = "(?:#{ATOM}|#{QUOTED_STRING})".freeze
      DOMAIN = "#{SUB_DOMAIN}(?:\\x2e#{SUB_DOMAIN})*".freeze
      LOCAL_PART = "#{WORD}(?:\\x2e#{WORD})*".freeze
      ADDR_SPEC = "#{LOCAL_PART}\\x40#{DOMAIN}".freeze

      EMAIL_REGEXP_WHOLE = Regexp.new("\\A#{ADDR_SPEC}\\z", Regexp::NOENCODING)
      EMAIL_REGEXP_PART = Regexp.new(ADDR_SPEC.to_s, Regexp::NOENCODING)
      EMAIL = EmailDecorator.new(EMAIL_REGEXP_WHOLE)
      GIT_URL = GitUrlDecorator.new(URI::DEFAULT_PARSER.make_regexp(%w[http https git]))

      # The block will be evaluated in the context of the schema validator used
      # by class `JsonMessage` viz. `Membrane`.
      Boolean = ->(*_) { bool }
    end

    class MetadataMessage < Message
      required :guid, String
      required :url, HTTPS_URL
      required :created_at, Date
      required :updated_at, Date
    end

    class PaginatedResponse < Message
      required :total_results, Integer
      required :prev_url, Message::HTTPS_URL
      required :next_url, Message::HTTPS_URL
      required :resources, [{ metadata: Hash, entity: Hash }]
    end

    class Response < Message
      required :metadata, Hash
      required :entity, Hash
    end
  end
end
