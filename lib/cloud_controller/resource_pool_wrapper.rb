module VCAP::CloudController
  class ResourcePoolWrapper
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def call
      fingerprints_all_clientside_bits = parse_fingerprints_in(body)
      fingerprints_existing_in_blobstore = ResourcePool.instance.match_resources(fingerprints_all_clientside_bits)
      MultiJson.dump(fingerprints_existing_in_blobstore)
    end

    private

    def parse_fingerprints_in(payload)
      fingerprints_all_clientside_bits = MultiJson.load(payload)
      unless fingerprints_all_clientside_bits.is_a?(Array)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'must be an array.')
      end
      fingerprints_all_clientside_bits
    rescue MultiJson::ParseError => e
      raise CloudController::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end
  end
end
