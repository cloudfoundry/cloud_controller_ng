# Copyright (c) 2009-2012 VMware, Inc.

require "json_message"
require "rfc822"

module VCAP::RestAPI
  class Message < JsonMessage

    # The schema validator used by class `JsonMessage` calls the `inspect`
    # method on the schema to get a description of the schema. We wrap the
    # schema object so that the `inspect` method generates a readable
    # description for us through `VCAP::RestAPI::Message#schema_doc` method.
    class ReadableSchema
      def initialize(schema, description = nil)
        @schema = schema
        @description = description
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

    URL       = ReadableSchema.new(URI::regexp(%w(http https)),
                             "String /URL_REGEX/")
    HTTPS_URL = ReadableSchema.new(URI::regexp("https"),
                                   "String /HTTPS_URL_REGEX/")
    EMAIL     = ReadableSchema.new(RFC822::EMAIL_REGEXP_WHOLE,
                                   "String /EMAIL_REGEX/")
    Boolean   = Symbol
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
