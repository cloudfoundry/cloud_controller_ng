require 'vcap/json_message'
require 'rfc822'

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

      URL = UrlDecorator.new(URI::DEFAULT_PARSER.make_regexp(%w(http https)))
      HTTPS_URL = HttpsUrlDecorator.new(URI::DEFAULT_PARSER.make_regexp('https'))
      EMAIL = EmailDecorator.new(RFC822::EMAIL_REGEXP_WHOLE)
      GIT_URL = GitUrlDecorator.new(URI::DEFAULT_PARSER.make_regexp(%w(http https git)))

      # The block will be evaluated in the context of the schema validator used
      # by class `JsonMessage` viz. `Membrane`.
      Boolean = lambda { |*_| bool }
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
