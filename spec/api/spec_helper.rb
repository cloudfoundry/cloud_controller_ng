# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

Dir[File.expand_path("../helpers/*", __FILE__)].each do |file|
  require file
end

module VCAP::CloudController::ApiSpecHelper
  def app
    VCAP::CloudController::Controller.new
  end

  def headers_for(user, proxy_user = nil, https = false)
    headers = {}
    # FIXME: we should be using the UAA now, so fix this
    # headers['HTTP_AUTHORIZATION'] = VCAP::CloudController::Notary.new(TOKEN_SECRET).encode(user.email) if user
    headers['HTTP_AUTHORIZATION'] = user.email if user
    headers['HTTP_PROXY_USER']    = proxy_user.email if proxy_user
    headers['X-Forwarded_Proto']  = "https" if https
    headers
  end

  def json_headers(headers)
    headers.merge({ "CONTENT_TYPE" => "application/json"})
  end

  shared_examples "a CloudController API" do |opts|
    [:required_attributes, :unique_attributes, :basic_attributes,
     :extra_attributes, :sensitive_attributes].each do |k|
      opts[k] ||= []
      opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
      opts[k].map! { |v| v.to_s }
    end

    [:many_to_many_collection_ids, :one_to_many_collection_ids].each do |k|
      opts[k] ||= {}
    end

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    let(:decoded_response) do
      Yajl::Parser.parse(last_response.body)
    end

    include_examples "creating and updating", opts
    include_examples "reading a valid object", opts
    include_examples "deleting a valid object", opts
    include_examples "operations on an invalid object", opts
    include_examples "collection operations", opts

    # FIXME: add update of :created_at, :updated_at, :id, should all fail
  end

  # FIXME: copied (and modified) from model spec helper, unify
  class TemplateObj
    attr_accessor :attributes

    def initialize(klass, attribute_names)
      @klass = klass
      @obj = klass.make
      @attributes = {}
      attribute_names.each do |attr|
        attr = attr.to_s.chomp("_id")
        key = if @klass.associations.include?(attr.to_sym)
                "#{attr}_id"
              else
                attr
              end
        @attributes[key] = @obj.send(attr) if @obj.respond_to?(attr)
      end
      hash
    end

    def refresh
      @klass.associations.each do |name|
        association = @obj.send(name)
        key = "#{name}_id"
        @attributes[key] = association.class.make.id if @attributes[key]
      end
    end
  end
end

RSpec.configure do |conf|
  conf.include VCAP::CloudController::ApiSpecHelper
end
