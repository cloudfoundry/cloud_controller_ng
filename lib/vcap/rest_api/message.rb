# Copyright (c) 2009-2012 VMware, Inc.

require "json_message"
require "rfc822"

module VCAP::RestAPI
  class Message < JsonMessage
    URL       = URI::regexp(%w(http https))
    HTTPS_URL = URI::regexp("https")
    EMAIL     = RFC822::EMAIL_REGEXP_WHOLE
    Boolean   = Symbol

    def self.register_type(schema, doc_str)
      @doc_overrides ||= {}
      @doc_overrides[schema.to_s] = doc_str
    end

    def self.schema_doc(schema)
      str = schema.to_s
      # we do a loop in case of nested attributes,
      # i.e. a regstisterd override inside another type
      @doc_overrides.each do |k, v|
        str.sub!(k, v)
      end
      str
    end

    register_type(HTTPS_URL, "String /HTTPS_URL_REGEX/")
    register_type(URL, "String /URL_REGEX/")
    register_type(EMAIL, "String /EMAIL_REGEX/")
    register_type(Boolean, "Boolean")
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
