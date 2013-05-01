# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::RestAPI
  #
  # Query against a model using a query string received via http query
  # parameters.
  #
  # Note: we use both a model and a dataset because we need to know properties
  # about the model.  We also want to query against a potentially already
  # filtered dataset.  Since datasets aren't bound to a particular model,
  # we need to pass both pieces of infomration.
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
    # @param [Sequel::Dataset] ds The dataset to query against
    #
    # @param [Set] queryable_attributes The attributes allowed to be used as
    # keys in a query.
    #
    # @param [Hash] query_params A hash containing the full set of http
    # query parameters.  Currently, only :q is extracted and used as the query
    # string.  The :q entry is a key value pair of the form 'key:value'
    def initialize(model, ds, queryable_attributes, query_params)
      @model = model
      @ds = ds
      @queryable_attributes = queryable_attributes
      @query = query_params[:q]
    end

    # Return the dataset associated with the query.  Note that this does not
    # result in fetching records from the db.
    #
    # @return [Sequel::Dataset]
    def filtered_dataset
      @ds.filter(filter_args_from_query)
    end

    # Return the dataset for the supplied query.
    # Note that this does not result in fetching records from the db.
    #
    # @param [Sequel::Model] model The model to query against
    #
    # @param [Sequel::Dataset] ds The dataset to query against
    #
    # @param [Set] queryable_attributes The attributes allowed to be used as
    # keys in a query.
    #
    # @param [Hash] query_params A hash containing the full set of http
    # query parameters.  Currently, only :q is extracted and used as the query
    # string.  The :q entry is a key value pair of the form 'key:value'
    #
    # @return [Sequel::Dataset]
    def self.filtered_dataset_from_query_params(model,
                                                ds,
                                                queryable_attributes,
                                                query_params)
      self.new(model, ds, queryable_attributes, query_params).filtered_dataset
    end

    private

    def filter_args_from_query
      return {} unless query

      keyvals = parse

      filter = {}
      keyvals.collect! do |key, val|
        key, val = clean_up_foreign_key(key, val)
        key, val = clean_up_boolean(key, val)
        key, val = clean_up_integer(key, val)

        filter[key] = val
      end

      filter
    end

    def parse
      segments = query.split(";")

      segments.collect do |segment|
        key, value, extra = segment.split(":")

        unless extra.nil?
          raise VCAP::Errors::BadQueryParameter.new(segment)
        end

        unless queryable_attributes.include?(key)
          raise VCAP::Errors::BadQueryParameter.new(key)
        end

        [key.to_sym, value]
      end
    end

    def clean_up_foreign_key(q_key, q_val)
      return [q_key, q_val] unless q_key =~ /(.*)_(gu)?id$/

      attr = $1

      f_key = if model.associations.include?(attr.to_sym)
        attr.to_sym
      elsif model.associations.include?(attr.pluralize.to_sym)
        attr.pluralize.to_sym
      end

      # One could argue that this should be a server error.  It means
      # that a query key came in for an attribute that is explicitly
      # in the queryable_attributes, but is not a column or an association.
      raise VCAP::Errors::BadQueryParameter.new(q_key) unless f_key

      other_model = model.association_reflection(f_key).associated_class
      id_key = other_model.columns.include?(:guid) ? :guid : :id
      f_val = other_model.filter(id_key => q_val)

      [f_key, f_val]
    end

    TINYINT_TYPE = "tinyint(1)".freeze
    TINYINT_FROM_TRUE_FALSE = {"t" => 1, "f" => 0}.freeze

    # Sequel uses tinyint(1) to store booleans in Mysql.
    # Mysql does not support using 't'/'f' for querying.
    def clean_up_boolean(q_key, q_val)
      column = model.db_schema[q_key.to_sym]
      unless column && column[:type] == :boolean
        return [q_key, q_val]
      end

      if column[:db_type] == TINYINT_TYPE
        q_val = TINYINT_FROM_TRUE_FALSE.fetch(q_val, q_val)
      end

      [q_key, q_val]
    end

    def clean_up_integer(q_key, q_val)
      column = model.db_schema[q_key.to_sym]
      unless column
        return [q_key, q_val]
      end

      if column[:type] == :integer
        q_val = q_val.to_i if q_val
      end

      [q_key, q_val]
    end

    attr_accessor :model, :access_filter, :queryable_attributes, :query
  end
end
