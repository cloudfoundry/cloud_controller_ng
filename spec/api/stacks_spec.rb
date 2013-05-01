# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Stack do
    it_behaves_like "a CloudController API", {
      :path                 => "/v2/stacks",
      :model                => Models::Stack,
      :read_only            => true,
      :basic_attributes     => [:name, :description],
      :required_attributes  => [:name, :description],
      :unique_attributes    => :name,
      :queryable_attributes => :name,
    }

    include_examples "uaa authenticated api", path: "/v2/stacks"
    include_examples "querying objects", path: "/v2/stacks", model: Models::Stack, queryable_attributes: [:name]
    include_examples "enumerating objects", path: "/v2/stacks", model: Models::Stack
    include_examples "reading a valid object", path: "/v2/stacks", model: Models::Stack, basic_attributes: [:name, :description]

    def self.it_responds_to(verb, path, expected_status, expected_error)
      before(:all) { send(verb, path, {}, json_headers(admin_headers)) }

      it "returns #{expected_status}" do
        last_response.status.should == expected_status
      end

      it_behaves_like "a vcap rest error response", expected_error
    end

    describe "GET /v2/stacks/:invalid_id/" do
      it_responds_to :get, "/v2/stacks/999999", 404, "not be found: 999999"
    end

    describe "POST /v2/stacks/:invalid_id/" do
      it_responds_to :post, "/v2/stacks/999999", 404, /Unknown request/
    end

    describe "PUT /v2/stacks/:invalid_id/" do
      it_responds_to :put, "/v2/stacks/999999", 404, /Unknown request/
    end

    describe "DELETE /v2/stacks/:invalid_id/" do
      it_responds_to :delete, "/v2/stacks/999999", 404, /Unknown request/
    end
  end
end
