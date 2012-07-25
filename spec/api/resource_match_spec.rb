# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require File.expand_path("../../resource_pool/spec_helper", __FILE__)

describe VCAP::CloudController::ResourceMatch do
  include_context "resource pool", VCAP::CloudController::FilesystemPool

  before(:all) do
    FilesystemPool.add_directory(tmpdir)
  end

  def resource_match_request(matches, non_matches)
    user = Models::User.make(:admin => true, :active => true)
    req = Yajl::Encoder.encode(matches + non_matches)
    put "/v2/resource_match", req, json_headers(headers_for(user))
    last_response.status.should == 200
    resp = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
    resp.should == matches
  end

  describe "GET /v2/resource_match" do
    it "should return an empty list when no resources match" do
      resource_match_request([], [dummy_descriptor])
    end

    it "should return a resource that matches" do
      resource_match_request([@descriptors.first], [dummy_descriptor])
    end

    it "should return many resources that match" do
      resource_match_request(@descriptors, [dummy_descriptor])
    end
  end
end
