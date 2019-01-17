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
      class MetricTagValue < ::Protobuf::Message
        class DynamicValue < ::Protobuf::Enum
          define :DynamicValueInvalid, 0
          define :INDEX, 1
          define :INSTANCE_GUID, 2
        end

      end



      ##
      # Message Fields
      #
      class MetricTagValue
        optional :string, :static, 1
        optional ::Diego::Bbs::Models::MetricTagValue::DynamicValue, :dynamic, 2
      end

    end

  end

end

