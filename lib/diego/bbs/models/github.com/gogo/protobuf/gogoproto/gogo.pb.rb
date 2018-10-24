# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


##
# Imports
#
require 'google/protobuf/descriptor.pb'

module Gogoproto
  ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

  ##
  # File Options
  #
  set_option :java_package, "com.google.protobuf"
  set_option :java_outer_classname, "GoGoProtos"


  ##
  # Extended Message Fields
  #
  class ::Google::Protobuf::EnumOptions < ::Protobuf::Message
    optional :bool, :".gogoproto.goproto_enum_prefix", 62001, :extension => true
    optional :bool, :".gogoproto.goproto_enum_stringer", 62021, :extension => true
    optional :bool, :".gogoproto.enum_stringer", 62022, :extension => true
    optional :string, :".gogoproto.enum_customname", 62023, :extension => true
  end

  class ::Google::Protobuf::EnumValueOptions < ::Protobuf::Message
    optional :string, :".gogoproto.enumvalue_customname", 66001, :extension => true
  end

  class ::Google::Protobuf::FileOptions < ::Protobuf::Message
    optional :bool, :".gogoproto.goproto_getters_all", 63001, :extension => true
    optional :bool, :".gogoproto.goproto_enum_prefix_all", 63002, :extension => true
    optional :bool, :".gogoproto.goproto_stringer_all", 63003, :extension => true
    optional :bool, :".gogoproto.verbose_equal_all", 63004, :extension => true
    optional :bool, :".gogoproto.face_all", 63005, :extension => true
    optional :bool, :".gogoproto.gostring_all", 63006, :extension => true
    optional :bool, :".gogoproto.populate_all", 63007, :extension => true
    optional :bool, :".gogoproto.stringer_all", 63008, :extension => true
    optional :bool, :".gogoproto.onlyone_all", 63009, :extension => true
    optional :bool, :".gogoproto.equal_all", 63013, :extension => true
    optional :bool, :".gogoproto.description_all", 63014, :extension => true
    optional :bool, :".gogoproto.testgen_all", 63015, :extension => true
    optional :bool, :".gogoproto.benchgen_all", 63016, :extension => true
    optional :bool, :".gogoproto.marshaler_all", 63017, :extension => true
    optional :bool, :".gogoproto.unmarshaler_all", 63018, :extension => true
    optional :bool, :".gogoproto.stable_marshaler_all", 63019, :extension => true
    optional :bool, :".gogoproto.sizer_all", 63020, :extension => true
    optional :bool, :".gogoproto.goproto_enum_stringer_all", 63021, :extension => true
    optional :bool, :".gogoproto.enum_stringer_all", 63022, :extension => true
    optional :bool, :".gogoproto.unsafe_marshaler_all", 63023, :extension => true
    optional :bool, :".gogoproto.unsafe_unmarshaler_all", 63024, :extension => true
    optional :bool, :".gogoproto.goproto_extensions_map_all", 63025, :extension => true
    optional :bool, :".gogoproto.goproto_unrecognized_all", 63026, :extension => true
    optional :bool, :".gogoproto.gogoproto_import", 63027, :extension => true
    optional :bool, :".gogoproto.protosizer_all", 63028, :extension => true
    optional :bool, :".gogoproto.compare_all", 63029, :extension => true
  end

  class ::Google::Protobuf::MessageOptions < ::Protobuf::Message
    optional :bool, :".gogoproto.goproto_getters", 64001, :extension => true
    optional :bool, :".gogoproto.goproto_stringer", 64003, :extension => true
    optional :bool, :".gogoproto.verbose_equal", 64004, :extension => true
    optional :bool, :".gogoproto.face", 64005, :extension => true
    optional :bool, :".gogoproto.gostring", 64006, :extension => true
    optional :bool, :".gogoproto.populate", 64007, :extension => true
    optional :bool, :".gogoproto.stringer", 67008, :extension => true
    optional :bool, :".gogoproto.onlyone", 64009, :extension => true
    optional :bool, :".gogoproto.equal", 64013, :extension => true
    optional :bool, :".gogoproto.description", 64014, :extension => true
    optional :bool, :".gogoproto.testgen", 64015, :extension => true
    optional :bool, :".gogoproto.benchgen", 64016, :extension => true
    optional :bool, :".gogoproto.marshaler", 64017, :extension => true
    optional :bool, :".gogoproto.unmarshaler", 64018, :extension => true
    optional :bool, :".gogoproto.stable_marshaler", 64019, :extension => true
    optional :bool, :".gogoproto.sizer", 64020, :extension => true
    optional :bool, :".gogoproto.unsafe_marshaler", 64023, :extension => true
    optional :bool, :".gogoproto.unsafe_unmarshaler", 64024, :extension => true
    optional :bool, :".gogoproto.goproto_extensions_map", 64025, :extension => true
    optional :bool, :".gogoproto.goproto_unrecognized", 64026, :extension => true
    optional :bool, :".gogoproto.protosizer", 64028, :extension => true
    optional :bool, :".gogoproto.compare", 64029, :extension => true
  end

  class ::Google::Protobuf::FieldOptions < ::Protobuf::Message
    optional :bool, :".gogoproto.nullable", 65001, :extension => true
    optional :bool, :".gogoproto.embed", 65002, :extension => true
    optional :string, :".gogoproto.customtype", 65003, :extension => true
    optional :string, :".gogoproto.customname", 65004, :extension => true
    optional :string, :".gogoproto.jsontag", 65005, :extension => true
    optional :string, :".gogoproto.moretags", 65006, :extension => true
    optional :string, :".gogoproto.casttype", 65007, :extension => true
    optional :string, :".gogoproto.castkey", 65008, :extension => true
    optional :string, :".gogoproto.castvalue", 65009, :extension => true
    optional :bool, :".gogoproto.stdtime", 65010, :extension => true
    optional :bool, :".gogoproto.stdduration", 65011, :extension => true
  end

end

