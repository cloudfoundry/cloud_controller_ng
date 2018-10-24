# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'error.pb'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class DomainsResponse < ::Protobuf::Message; end
      class UpsertDomainResponse < ::Protobuf::Message; end
      class UpsertDomainRequest < ::Protobuf::Message; end


      ##
      # File Options
      #
      set_option :".gogoproto.equal_all", false


      ##
      # Message Fields
      #
      class DomainsResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        repeated :string, :domains, 2
      end

      class UpsertDomainResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

      class UpsertDomainRequest
        optional :string, :domain, 1
        optional :uint32, :ttl, 2
      end

    end

  end

end

