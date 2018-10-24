# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class ImageLayer < ::Protobuf::Message
        class DigestAlgorithm < ::Protobuf::Enum
          define :DigestAlgorithmInvalid, 0
          define :sha256, 1
          define :sha512, 2
        end

        class MediaType < ::Protobuf::Enum
          define :MediaTypeInvalid, 0
          define :tgz, 1
          define :tar, 2
          define :zip, 3
        end

        class Type < ::Protobuf::Enum
          define :LayerTypeInvalid, 0
          define :shared, 1
          define :exclusive, 2
        end

      end



      ##
      # Message Fields
      #
      class ImageLayer
        optional :string, :name, 1, :".gogoproto.jsontag" => "name,omitempty"
        optional :string, :url, 2
        optional :string, :destination_path, 3
        optional ::Diego::Bbs::Models::ImageLayer::Type, :layer_type, 4, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "layer_type"
        optional ::Diego::Bbs::Models::ImageLayer::MediaType, :media_type, 5, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "media_type"
        optional ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm, :digest_algorithm, 6, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "digest_algorithm,omitempty"
        optional :string, :digest_value, 7, :".gogoproto.jsontag" => "digest_value,omitempty"
      end

    end

  end

end

