module VCAP::CloudController
  module ParamsHashifier
    attr_reader :hashed_params
    def hashify_params
      @hashed_params = params.to_unsafe_hash
    end
  end
end
