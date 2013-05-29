require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Stack do
    include_examples "uaa authenticated api", path: "/v2/stacks"
    include_examples "querying objects", path: "/v2/stacks", model: Models::Stack, queryable_attributes: [:name], ci_attributes: [:name]
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

    describe "rejects changes" do
      def self.it_responds_unknown_request
        it "returns 404" do
          last_response.status.should == 404
        end

        it_behaves_like "a vcap rest error response", /Unknown request/
      end

      def obj
        @obj ||= Models::Stack.make
      end

      describe "POST /v2/stacks/" do
        before(:all) { post("/v2/stacks", {}, json_headers(admin_headers)) }
        it_responds_unknown_request
      end

      describe "PUT /v2/stacks/:id" do
        before(:all) { put("/v2/stacks/#{obj.guid}", {}, json_headers(admin_headers)) }
        it_responds_unknown_request
      end

      describe "DELETE /v2/stacks/:id" do
        before(:all) { delete("/v2/stacks/#{obj.guid}", {}, json_headers(admin_headers)) }
        it_responds_unknown_request
      end
    end
  end
end
