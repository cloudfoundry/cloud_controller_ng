# Copyright (c) 2009-2012 VMware, Inc.

require "sequel"
require "sequel/adapters/oracle"

Sequel::Oracle::Database.class_eval do
  alias_method :initialize_original, :initialize
  alias_method :oracle_column_type_original, :oracle_column_type
  
  def initialize(opts={})
    initialize_original(opts)
    @conversion_procs = {
      :blob=>lambda{|b| Sequel::SQL::Blob.new(b.read)},
      :clob=>lambda{|b| b.read},
      :char=>lambda{|b|
        if b == 'Y'
          true
        elsif b == 'N'
          false
        else
          b 
        end
      }
    }
  end
  
  def oracle_column_type(h)
    case h[:oci8_type]
    when :char
      case h[:char_size]
      when 1
        :boolean
      else
        oracle_column_type_original(h)
      end
    else
      oracle_column_type_original(h)
    end
  end
end
