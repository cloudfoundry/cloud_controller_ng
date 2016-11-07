# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'google/protobuf/descriptor.pb'

module Gogoproto

  ##
  # Extended Message Fields
  #
  class ::Google::Protobuf::EnumOptions < ::Protobuf::Message
    optional :bool, :goproto_enum_prefix, 62001, :extension => true
    optional :bool, :goproto_enum_stringer, 62021, :extension => true
    optional :bool, :enum_stringer, 62022, :extension => true
    optional :string, :enum_customname, 62023, :extension => true
  end

  class ::Google::Protobuf::EnumValueOptions < ::Protobuf::Message
    optional :string, :enumvalue_customname, 66001, :extension => true
  end

  class ::Google::Protobuf::FileOptions < ::Protobuf::Message
    optional :bool, :goproto_getters_all, 63001, :extension => true
    optional :bool, :goproto_enum_prefix_all, 63002, :extension => true
    optional :bool, :goproto_stringer_all, 63003, :extension => true
    optional :bool, :verbose_equal_all, 63004, :extension => true
    optional :bool, :face_all, 63005, :extension => true
    optional :bool, :gostring_all, 63006, :extension => true
    optional :bool, :populate_all, 63007, :extension => true
    optional :bool, :stringer_all, 63008, :extension => true
    optional :bool, :onlyone_all, 63009, :extension => true
    optional :bool, :equal_all, 63013, :extension => true
    optional :bool, :description_all, 63014, :extension => true
    optional :bool, :testgen_all, 63015, :extension => true
    optional :bool, :benchgen_all, 63016, :extension => true
    optional :bool, :marshaler_all, 63017, :extension => true
    optional :bool, :unmarshaler_all, 63018, :extension => true
    optional :bool, :stable_marshaler_all, 63019, :extension => true
    optional :bool, :sizer_all, 63020, :extension => true
    optional :bool, :goproto_enum_stringer_all, 63021, :extension => true
    optional :bool, :enum_stringer_all, 63022, :extension => true
    optional :bool, :unsafe_marshaler_all, 63023, :extension => true
    optional :bool, :unsafe_unmarshaler_all, 63024, :extension => true
    optional :bool, :goproto_extensions_map_all, 63025, :extension => true
    optional :bool, :goproto_unrecognized_all, 63026, :extension => true
    optional :bool, :gogoproto_import, 63027, :extension => true
    optional :bool, :protosizer_all, 63028, :extension => true
    optional :bool, :compare_all, 63029, :extension => true
  end

  class ::Google::Protobuf::MessageOptions < ::Protobuf::Message
    optional :bool, :goproto_getters, 64001, :extension => true
    optional :bool, :goproto_stringer, 64003, :extension => true
    optional :bool, :verbose_equal, 64004, :extension => true
    optional :bool, :face, 64005, :extension => true
    optional :bool, :gostring, 64006, :extension => true
    optional :bool, :populate, 64007, :extension => true
    optional :bool, :stringer, 67008, :extension => true
    optional :bool, :onlyone, 64009, :extension => true
    optional :bool, :equal, 64013, :extension => true
    optional :bool, :description, 64014, :extension => true
    optional :bool, :testgen, 64015, :extension => true
    optional :bool, :benchgen, 64016, :extension => true
    optional :bool, :marshaler, 64017, :extension => true
    optional :bool, :unmarshaler, 64018, :extension => true
    optional :bool, :stable_marshaler, 64019, :extension => true
    optional :bool, :sizer, 64020, :extension => true
    optional :bool, :unsafe_marshaler, 64023, :extension => true
    optional :bool, :unsafe_unmarshaler, 64024, :extension => true
    optional :bool, :goproto_extensions_map, 64025, :extension => true
    optional :bool, :goproto_unrecognized, 64026, :extension => true
    optional :bool, :protosizer, 64028, :extension => true
    optional :bool, :compare, 64029, :extension => true
  end

  class ::Google::Protobuf::FieldOptions < ::Protobuf::Message
    optional :bool, :nullable, 65001, :extension => true
    optional :bool, :embed, 65002, :extension => true
    optional :string, :customtype, 65003, :extension => true
    optional :string, :customname, 65004, :extension => true
    optional :string, :jsontag, 65005, :extension => true
    optional :string, :moretags, 65006, :extension => true
    optional :string, :casttype, 65007, :extension => true
    optional :string, :castkey, 65008, :extension => true
    optional :string, :castvalue, 65009, :extension => true
    optional :bool, :stdtime, 65010, :extension => true
    optional :bool, :stdduration, 65011, :extension => true
  end

end

