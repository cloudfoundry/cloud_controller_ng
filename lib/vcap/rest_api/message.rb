# Copyright (c) 2009-2012 VMware, Inc.

require "json_message"
require "rfc822"

module VCAP::RestAPI
  class Message < JsonMessage

    def self.readable_schema(schema, description)
      # The schema validator used by JsonMessage calls `inspect` to get a
      # description of the schema. We patch the `inspect` method here so that
      # it can generate the readable documentation for us in the `schema_doc`
      # method.
      def schema.inspect
        description
      end

      schema
    end

    def self.schema_doc(schema)
      schema.deparse
    end

    unless const_defined?(:URL)
      URL = self.readable_schema(URI::regexp(%w(http https)),
                                 "String /URL_REGEX/")
    end

    unless const_defined?(:HTTPS_URL)
      HTTPS_URL = self.readable_schema(URI::regexp("https"),
                                       "String /HTTPS_URL_REGEX/")
    end

    unless const_defined?(:EMAIL)
      EMAIL     = self.readable_schema(RFC822::EMAIL_REGEXP_WHOLE,
                                       "String /EMAIL_REGEX/")
    end

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
