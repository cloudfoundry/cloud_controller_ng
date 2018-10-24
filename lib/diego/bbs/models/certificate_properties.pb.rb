# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class CertificateProperties < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class CertificateProperties
        repeated :string, :organizational_unit, 1
      end

    end

  end

end

