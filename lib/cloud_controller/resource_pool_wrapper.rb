module VCAP::CloudController
  class ResourcePoolWrapper
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def call
      fingerprints_all_clientside_bits = parse_fingerprints_in(body)
      fingerprints_existing_in_blobstore = ResourcePool.instance.match_resources(fingerprints_all_clientside_bits)
      Oj.dump(fingerprints_existing_in_blobstore)
    end

    private

    def parse_fingerprints_in(payload)
      begin
        fingerprints_all_clientside_bits = Oj.load(payload)
      rescue StandardError => e
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'must be an array.') unless fingerprints_all_clientside_bits.is_a?(Array)

      fingerprints_all_clientside_bits
    end
  end
end
