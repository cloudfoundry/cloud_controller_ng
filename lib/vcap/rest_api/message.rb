require 'json_message'
require 'rfc822'

module VCAP
  module RestAPI
    class Message < JsonMessage
      # The schema validator used by class `JsonMessage` calls the `inspect`
      # method on the regexp object to get a description of the regex. We tweak
      # the regexp object so that the `inspect` method generates a readable
      # description for us through `VCAP::RestAPI::Message#schema_doc` method.
      def self.readable_regexp(regexp, description, default_error_message)
        regexp.define_singleton_method(:inspect) do
          description
        end

        regexp.define_singleton_method(:to_s) do
          inspect
        end

        regexp.define_singleton_method(:default_error_message) do
          default_error_message
        end

        regexp
      end

      def self.schema_doc(schema)
        schema.deparse
      end

      URL       = readable_regexp(URI.regexp(%w(http https)),
                                  'String /URL_REGEX/',
                                  'must be a valid URL')
      HTTPS_URL = readable_regexp(URI.regexp('https'),
                                  'String /HTTPS_URL_REGEX/',
                                  'must be a valid HTTPS URL')
      EMAIL     = readable_regexp(RFC822::EMAIL_REGEXP_WHOLE,
                                  'String /EMAIL_REGEX/',
                                  'must be a valid email')
      GIT_URL   = readable_regexp(URI.regexp(%w(http https git)),
                                  'String /GIT_URL_REGEX/',
                                  'must be a valid git URL')

      # The block will be evaluated in the context of the schema validator used
      # by class `JsonMessage` viz. `Membrane`.
      Boolean   = lambda { |*_| bool }
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
