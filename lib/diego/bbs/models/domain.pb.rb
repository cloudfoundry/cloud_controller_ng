## Generated from domain.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class DomainsResponse
        include Beefcake::Message
      end

      class UpsertDomainResponse
        include Beefcake::Message
      end

      class UpsertDomainRequest
        include Beefcake::Message
      end

      class DomainsResponse
        optional :error, Error, 1
        repeated :domains, :string, 2
      end

      class UpsertDomainResponse
        optional :error, Error, 1
      end

      class UpsertDomainRequest
        optional :domain, :string, 1
        optional :ttl, :uint32, 2
      end
    end
  end
end
