require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ResourceMatchesController do
    include_context "resource pool"

    before do
      @resource_pool.add_directory(@tmpdir)
    end

    def resource_match_request(verb, path, matches, non_matches)
      user = User.make(:admin => true, :active => true)
      req = Yajl::Encoder.encode(matches + non_matches)
      send(verb, path, req, json_headers(headers_for(user)))
      expect(last_response.status).to eq(200)
      resp = Yajl::Parser.parse(last_response.body)
      expect(resp).to eq(matches)
    end

    describe "PUT /v2/resource_match" do
      it "should return an empty list when no resources match" do
        resource_match_request(:put, "/v2/resource_match", [], [@dummy_descriptor])
      end

      it "should return a resource that matches" do
        resource_match_request(:put, "/v2/resource_match", [@descriptors.first], [@dummy_descriptor])
      end

      it "should return many resources that match" do
        resource_match_request(:put, "/v2/resource_match", @descriptors, [@dummy_descriptor])
      end
    end
  end
end
