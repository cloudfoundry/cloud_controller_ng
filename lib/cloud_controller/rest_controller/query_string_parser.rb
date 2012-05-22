# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module QueryStringParser
    def self.data_set_from_query_params(model, access_filter, opts)
      filter_args = filter_args_from_query_params(model, opts[:q])
      ds = model.filter(access_filter).filter(filter_args)
    end

    def self.validate_query_params(query_params)
      # FIXME: raise here if the query params are malformed,
      # or don't exclusively use what we allow
    end

    def self.filter_args_from_query_params(model, query_params)
      return {} unless query_params
      validate_query_params(query_params)

      key, value = query_params.split(":")
      filter_args = nil

      if model.columns.include?(key.to_sym)
        filter_args = { key.to_sym => value }
      elsif key =~ /(.*)_id$/
        attr = $1
        attr_key = nil

        if model.associations.include?(attr.to_sym)
          attr_key = attr.to_sym
        elsif model.associations.include?(attr.pluralize.to_sym)
          attr_key = attr.pluralize.to_sym
        end

        if attr_key
          ar = model.association_reflection(attr_key)
          attr_model = ar.associated_class
          attr_val = attr_model.filter(:id => value)
          filter_args = { attr_key => attr_val }
        end
      end

      raise VCAP::CloudController::Errors::BadQueryParameter.new(key) unless filter_args
      filter_args
    end
  end
end
