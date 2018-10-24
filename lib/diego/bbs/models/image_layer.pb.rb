# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class ImageLayer < ::Protobuf::Message
        class DigestAlgorithm < ::Protobuf::Enum
          define :DigestAlgorithmInvalid, 0
          define :SHA256, 1
          define :SHA512, 2
        end

        class MediaType < ::Protobuf::Enum
          define :MediaTypeInvalid, 0
          define :TGZ, 1
          define :TAR, 2
          define :ZIP, 3
        end

        class Type < ::Protobuf::Enum
          define :LayerTypeInvalid, 0
          define :SHARED, 1
          define :EXCLUSIVE, 2
        end

      end



      ##
      # Message Fields
      #
      class ImageLayer
        optional :string, :name, 1
        optional :string, :url, 2
        optional :string, :destination_path, 3
        optional ::Diego::Bbs::Models::ImageLayer::Type, :layer_type, 4
        optional ::Diego::Bbs::Models::ImageLayer::MediaType, :media_type, 5
        optional ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm, :digest_algorithm, 6
        optional :string, :digest_value, 7
      end

    end

  end

end

