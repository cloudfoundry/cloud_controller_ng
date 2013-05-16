# Copyright (c) 2009-2012 VMware, Inc.

#A plugin that makes available the column aliases created to aid
#in siutations like query translation
module Sequel::Plugins::VcapColumnAlias
  
  module ClassMethods

    def vcap_column_alias(alias_name, column)
      def_column_alias(alias_name, column)
      self.column_aliases = Hash.new if self.column_aliases.nil?
      self.column_aliases[alias_name] = column 
    end

    attr_accessor :column_aliases
  end
end
