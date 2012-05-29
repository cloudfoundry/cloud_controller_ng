# Copyright (c) 2009-2012 VMware, Inc.

require "json_message"
require "rfc822"

module VCAP::RestAPI
  # The gaps that this class addresses are being filed by the new Membrane
  # work.  Hence, this class isn't going to get full documentation or
  # specs.  It is implicitly covered by the specs for the caller, and
  # that should be good enough for now.
  #
  # Hopefully when we transition to Membrane, we'll get rid of this all
  # together.  If not, we'll add docs and specs then.
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
    required :id, String
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

# If we weren't moving to Membrane, this would get added to JsonSchema
# directly.  For now, there is no reason to go do a gem bump.
class JsonSchema
  def to_s
    @schema.to_s
  end
end
