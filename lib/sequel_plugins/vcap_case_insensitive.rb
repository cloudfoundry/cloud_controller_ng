# Copyright (c) 2009-2012 VMware, Inc.

module Sequel::Plugins::VcapCaseInsensitive
  # Depend on the validation_helpers plugin.
  def self.apply(model)
    model.plugin(:validation_helpers)
  end
  
  module InstanceMethods

    def validates_unique_ci(*atts)
      atts ||= []
      atts = Array[atts] unless atts.is_a?(Array)
      atts << Hash.new unless atts.last.is_a?(Hash)
      
      if atts.last.is_a?(Hash) && atts.last.has_key?(:where)
        raise Sequel::Error, ":where is not a valid option with validates_unique_ci.  Use validates_unique."
      end
      
      if !db.use_lower_where? 
        return validates_unique(*atts)
      end
      
      atts.last[:where] = (proc do |ds, obj, cols|
        ds.where(cols.map do |c|
          v = obj.send(c)
          if obj.class.ci_attrs && obj.class.ci_attrs.include?(c) 
            v = v.downcase if v
            [Sequel.function(:lower, c) => v]
          else
            [c => v]
          end 
        end)
      end)
      validates_unique(*atts)
    end
  end

  module ClassMethods

    def ci_attributes(*attributes)
      self.ci_attrs = attributes
    end

    attr_accessor :ci_attrs
  end
end
