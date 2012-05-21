# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::RestAPI
  #
  # Query against a model using a query string received via http query
  # parameters.
  #
  #
  # TODO: >, < and * (at the end of strings only) will be added in the
  # future.
  #
  # TODO: add support for an array of q values.
  class Query

    # Create a new Query.
    #
    # @param [Sequel::Model] model The model to query against
    #
    # @param [Set] queryable_attributes The attributes allowed to be used as
    # keys in a query.
    #
    # @param [Hash] query_params A hash containing the full set of http
    # query parameters.  Currently, only :q is extracted and used as the query
    # string.  The :q entry is a key value pair of the form 'key:value'
    def initialize(model, access_filter, queryable_attributes, query_params)
      @model = model
      @access_filter = access_filter
      @queryable_attributes = queryable_attributes
      @query = query_params[:q]
    end

    # Return the dataset associated with the query.  Note that this does not
    # result in fetching records from the db.
    #
    # @return [Sequel::Dataset]
    def dataset
      model.filter(access_filter).filter(filter_args_from_query)
    end

    # Return the dataset for the supplied query.
    # Note that this does not result in fetching records from the db.
    #
    # @param [Sequel::Model] model The model to query against
    #
    # @param [Set] queryable_attributes The attributes allowed to be used as
    # keys in a query.
    #
    # @param [Hash] query_params A hash containing the full set of http
    # query parameters.  Currently, only :q is extracted and used as the query
    # string.  The :q entry is a key value pair of the form 'key:value'
    #
    # @return [Sequel::Dataset]
    def self.dataset_from_query_params(model,
                                       access_filter,
                                       queryable_attributes,
                                       query_params)
      self.new(model, access_filter, queryable_attributes, query_params).dataset
    end

    private

    def filter_args_from_query
      return {} unless query
      q_key, q_val = parse
      filter_args = nil

      if model.columns.include?(q_key)
        filter_args = { q_key => q_val }
      elsif q_key =~ /(.*)_id$/
        attr = $1

        f_key = if model.associations.include?(attr.to_sym)
          attr.to_sym
        elsif model.associations.include?(attr.pluralize.to_sym)
          attr.pluralize.to_sym
        end

        # One could argue that this should be a server error.  It means
        # that a query key came in for an attribute that is explicitly
        # in the queryable_attributes, but is not a column or an association.
        raise Errors::BadQueryParameter.new(q_key) unless f_key

        other_model = model.association_reflection(f_key).associated_class
        f_val = other_model.filter(:id => q_val)
        filter_args = { f_key => f_val }
      end

      filter_args
    end

    def parse
      key, value, extra = query.split(":")

      unless extra.nil?
        raise Errors::BadQueryParameter.new(query)
      end

      unless queryable_attributes.include?(key)
        raise Errors::BadQueryParameter.new(key)
      end

      [key.to_sym, value]
    end

    attr_accessor :model, :access_filter, :queryable_attributes, :query
  end
end
