# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

Dir[File.expand_path("../helpers/*", __FILE__)].each do |file|
  require file
end

module VCAP::CloudController::ApiSpecHelper
  include VCAP::CloudController
  include VCAP::CloudController::ModelSpecHelper

  def config
    config_file = File.expand_path("../../../config/cloud_controller.yml",
                                    __FILE__)
    VCAP::CloudController::Config.from_file(config_file)
  end

  def app
    VCAP::CloudController::Controller.new(config)
  end

  def headers_for(user, proxy_user = nil, https = false)
    headers = {}
    token_coder = CF::UAA::TokenCoder.new(config[:uaa][:resource_id],
                                          config[:uaa][:symmetric_secret],
                                          nil)
    unless user.nil?
      user_token = token_coder.encode( { :user_id => user.guid } )
      headers["HTTP_AUTHORIZATION"] = "bearer #{user_token}"
    end

    # FIXME: what is the story here?
    # headers["HTTP_PROXY_USER"]    = proxy_user.id if proxy_user

    headers["X-Forwarded_Proto"]  = "https" if https
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

  def should_not_receive_quota_call
    RestController::QuotaManager.should_not_receive(:fetch_quota_token).with(nil)
  end

  def should_receive_nil_quota_call
    t = RestController::QuotaManager::BlindApprovalToken.new
    t.should_receive(:commit)
    RestController::QuotaManager.should_receive(:fetch_quota_token).with(nil).and_return(t)
  end

  def should_receive_quota_call
    RestController::QuotaManager.should_not_receive(:fetch_quota_token).with(nil)
    RestController::QuotaManager.should_receive(:fetch_quota_token) do |arg|
      arg[:path].should_not be_nil
      arg[:body].should_not be_nil
      audit_data = arg[:body][:audit_data]
      audit_data.should be_a_kind_of(Hash) if audit_data
      RestController::QuotaManager::BlindApprovalToken.new
    end
  end

  shared_context "permissions" do
    before do
      @org_a = VCAP::CloudController::Models::Organization.make
      @org_a_manager = VCAP::CloudController::Models::User.make
      @org_a_member = VCAP::CloudController::Models::User.make
      @org_a_billing_manager = VCAP::CloudController::Models::User.make
      @org_a_auditor = VCAP::CloudController::Models::User.make
      @org_a.add_manager(@org_a_manager)
      @org_a.add_user(@org_a_member)
      @org_a.add_billing_manager(@org_a_billing_manager)
      @org_a.add_auditor(@org_a_auditor)

      @app_space_a = VCAP::CloudController::Models::AppSpace.make(:organization => @org_a)
      @app_space_a_manager = make_user_for_app_space(@app_space_a)
      @app_space_a_developer = make_user_for_app_space(@app_space_a)
      @app_space_a_auditor = make_user_for_app_space(@app_space_a)
      @app_space_a.add_manager(@app_space_a_manager)
      @app_space_a.add_developer(@app_space_a_developer)
      @app_space_a.add_auditor(@app_space_a_auditor)

      @org_b = VCAP::CloudController::Models::Organization.make
      @org_b_manager = VCAP::CloudController::Models::User.make
      @org_b_member = VCAP::CloudController::Models::User.make
      @org_b_billing_manager = VCAP::CloudController::Models::User.make
      @org_b_auditor = VCAP::CloudController::Models::User.make
      @org_b.add_manager(@org_b_manager)
      @org_b.add_user(@org_b_member)
      @org_b.add_billing_manager(@org_b_billing_manager)
      @org_b.add_auditor(@org_b_auditor)

      @app_space_b = VCAP::CloudController::Models::AppSpace.make(:organization => @org_b)
      @app_space_b_manager = make_user_for_app_space(@app_space_b)
      @app_space_b_developer = make_user_for_app_space(@app_space_b)
      @app_space_b_auditor = make_user_for_app_space(@app_space_b)
      @app_space_b.add_manager(@app_space_b_manager)
      @app_space_b.add_developer(@app_space_b_developer)
      @app_space_b.add_auditor(@app_space_b_auditor)

      @cf_admin = VCAP::CloudController::Models::User.make(:admin => true)
    end
  end

  shared_examples "a CloudController API" do |opts|
    [:required_attributes, :unique_attributes, :basic_attributes,
     :extra_attributes, :sensitive_attributes].each do |k|
      opts[k] ||= []
      opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
      opts[k].map! { |v| v.to_s }
    end

    [:many_to_many_collection_ids, :one_to_many_collection_ids,
     :many_to_one_collection_ids].each do |k|
      opts[k] ||= {}
    end

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    before do
      # force creation of the admin user used in the headers
      admin_headers
    end

    include_examples "enumerating objects", opts
    include_examples "creating and updating", opts
    include_examples "reading a valid object", opts
    include_examples "deleting a valid object", opts
    include_examples "operations on an invalid object", opts
    include_examples "collection operations", opts

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
end

RSpec.configure do |conf|
  conf.include VCAP::CloudController::RestController
  conf.include VCAP::CloudController::ApiSpecHelper
end
