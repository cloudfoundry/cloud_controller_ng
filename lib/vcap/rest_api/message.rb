# Copyright (c) 2009-2012 VMware, Inc.

require "json_message"
require "rfc822"

module VCAP::RestAPI
  class Message < JsonMessage

    # The schema validator used by class `JsonMessage` calls the `inspect`
    # method on the regexp object to get a description of the regex. We wrap
    # the regexp object so that the `inspect` method generates a readable
    # description for us through `VCAP::RestAPI::Message#schema_doc` method.
    class ReadableRegexp < Regexp
      def initialize(schema, description = nil)
        @schema = schema
        @description = description
      end

      def match(str)
        @schema.match(str)
      end

      def inspect
        return @description if @description
        @schema.inspect
      end

      def method_missing(symbol, *args, &block)
        @schema.send(symbol, *args, &block)
      end
    end

    def self.schema_doc(schema)
      schema.deparse
    end

    URL       = ReadableRegexp.new(URI::regexp(%w(http https)),
                                   "String /URL_REGEX/")
    HTTPS_URL = ReadableRegexp.new(URI::regexp("https"),
                                   "String /HTTPS_URL_REGEX/")
    EMAIL     = ReadableRegexp.new(RFC822::EMAIL_REGEXP_WHOLE,
                                   "String /EMAIL_REGEX/")

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
    required :resources, [ {:metadata => Hash, :entity => Hash} ]
  end

  class Response < Message
    required :metadata, Hash
    required :entity, Hash
  end
end
