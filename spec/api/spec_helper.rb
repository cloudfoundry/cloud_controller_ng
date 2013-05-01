# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../helpers/nginx_upload", __FILE__)

Dir[File.expand_path("../helpers/*", __FILE__)].each do |file|
  require file
end


# Ensures that entries are not returned ordered by the id field by
# default. Breaks the tests (deliberately) unless we order by id
# explicitly. In sqlite, the default ordering, although not guaranteed,
# is de facto by id. In postgres the order is random unless specified.

class VCAP::CloudController::Models::App
  set_dataset dataset.order(:guid)
end

module VCAP::CloudController::ApiSpecHelper
  include VCAP::CloudController
  include VCAP::CloudController::ModelSpecHelper

  HTTPS_ENFORCEMENT_SCENARIOS = [
    {:protocol => "http",  :config_setting => nil, :user => "user",  :success => true},
    {:protocol => "http",  :config_setting => nil, :user => "admin", :success => true},
    {:protocol => "https", :config_setting => nil, :user => "user",  :success => true},
    {:protocol => "https", :config_setting => nil, :user => "admin", :success => true},

    # Next with https_required
    {:protocol => "http",  :config_setting => :https_required, :user => "user",  :success => false},
    {:protocol => "http",  :config_setting => :https_required, :user => "admin", :success => false},
    {:protocol => "https", :config_setting => :https_required, :user => "user",  :success => true},
    {:protocol => "https", :config_setting => :https_required, :user => "admin", :success => true},

    # Finally with https_required_for_admins
    {:protocol => "http",  :config_setting => :https_required_for_admins, :user => "user",  :success => true},
    {:protocol => "http",  :config_setting => :https_required_for_admins, :user => "admin", :success => false},
    {:protocol => "https", :config_setting => :https_required_for_admins, :user => "user",  :success => true},
    {:protocol => "https", :config_setting => :https_required_for_admins, :user => "admin", :success => true}
  ]

  def app
    token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
    klass = Class.new(VCAP::CloudController::Controller)
    klass.use(NginxUpload)
    klass.new(config, token_decoder)
  end

  def headers_for(user, opts = {})
    opts = { :email => Sham.email,
             :https => false}.merge(opts)

    headers = {}
    token_coder = CF::UAA::TokenCoder.new(:audience_ids => config[:uaa][:resource_id],
                                          :skey => config[:uaa][:symmetric_secret],
                                          :pkey => nil)

    if user || opts[:admin_scope]
      user_token = token_coder.encode(
        :user_id => user ? user.guid : (rand * 1_000_000_000).ceil,
        :email => opts[:email],
        :scope => opts[:admin_scope] ? %w[cloud_controller.admin] : []
      )

      headers["HTTP_AUTHORIZATION"] = "bearer #{user_token}"
    end

    # FIXME: what is the story here?
    # headers["HTTP_PROXY_USER"]    = proxy_user.id if proxy_user

    headers["HTTP_X_FORWARDED_PROTO"] = "https" if opts[:https]
    headers
  end

  def json_headers(headers)
    headers.merge({ "CONTENT_TYPE" => "application/json"})
  end

  def decoded_response
    Yajl::Parser.parse(last_response.body)
  end

  def metadata
    decoded_response["metadata"]
  end

  def entity
    decoded_response["entity"]
  end

  def admin_headers
    @admin_headers ||= headers_for(VCAP::CloudController::Models::User.make(:admin => true))
  end

  shared_examples "a CloudController API" do |opts|
    [:required_attributes, :unique_attributes, :basic_attributes,
     :extra_attributes, :sensitive_attributes,
     :queryable_attributes].each do |k|
      opts[k] ||= []
      opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
      opts[k].map! { |v| v.to_s }
    end

    [:many_to_many_collection_ids, :one_to_many_collection_ids,
     :many_to_one_collection_ids, :one_to_many_collection_ids_without_url].each do |k|
      opts[k] ||= {}
    end

    include_examples "operations on an invalid object", opts
    include_examples "collection operations", opts

    if opts[:read_only]
      include_examples "rejects changes", opts
    else
      include_examples "creating and updating", opts
      include_examples "deleting a valid object", opts
    end

    # FIXME: add update of :created_at, :updated_at, :id, should all fail
  end

  shared_examples "return a vcap rest encoded object" do
    it "should return a metadata hash in the response" do
      metadata.should_not be_nil
      metadata.should be_a_kind_of(Hash)
    end

    it "should return an id in the metadata" do
      metadata["guid"].should_not be_nil
      # used to check if the id was an integer here, but now users
      # use uaa based ids, which are strings.
    end

    it "should return a url in the metadata" do
      metadata["url"].should_not be_nil
      metadata["url"].should be_a_kind_of(String)
    end

    it "should return an entity hash in the response" do
      entity.should_not be_nil
      entity.should be_a_kind_of(Hash)
    end
  end

  def resource_match_request(verb, path, matches, non_matches)
    user = Models::User.make(:admin => true, :active => true)
    req = Yajl::Encoder.encode(matches + non_matches)
    send(verb, path, req, json_headers(headers_for(user)))
    last_response.status.should == 200
    resp = Yajl::Parser.parse(last_response.body)
    resp.should == matches
  end
end

RSpec.configure do |conf|
  conf.include VCAP::CloudController::RestController
  conf.include VCAP::CloudController::ApiSpecHelper
end
