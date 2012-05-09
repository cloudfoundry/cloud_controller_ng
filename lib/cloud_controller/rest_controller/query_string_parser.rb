# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module QueryStringParser
    def self.data_set_from_query_params(model, query_params)
      return model.dataset unless query_params

      filter_args = filter_args_from_query_params(model, query_params)
      ds = model.filter(filter_args)
    end

    def self.validate_query_params(query_params)
      # FIXME: raise here if the query params are malformed,
      # or don't exclusively use what we allow
    end

    def self.filter_args_from_query_params(model, query_params)
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
          attr_model = VCAP::CloudController::Models.const_get(attr.camelize)
          attr_val = attr_model.filter(:id => value)
          filter_args = { attr_key => attr_val }
        end
      end

      raise VCAP::CloudController::BadQueryParameter.new(key) unless filter_args
      filter_args
    end
  end
end
