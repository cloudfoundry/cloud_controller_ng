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
      class CachedDependency < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class CachedDependency
        optional :string, :name, 1
        optional :string, :from, 2
        optional :string, :to, 3
        optional :string, :cache_key, 4
        optional :string, :log_source, 5
        optional :string, :checksum_algorithm, 6
        optional :string, :checksum_value, 7
      end

    end

  end

end

