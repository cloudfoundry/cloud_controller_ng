# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "operations on an invalid object" do |opts|
    describe "operations on an invalid object" do
      def self.it_responds_to(verb, path, expected_status, expected_error)
        before(:all) { send(verb, path, {}, json_headers(admin_headers)) }

        it "returns #{expected_status}" do
          last_response.status.should == expected_status
        end

        it_behaves_like "a vcap rest error response", expected_error
      end

      path = "#{opts[:path]}/999999"

      describe "GET #{opts[:path]}/:invalid_id/" do
        it_responds_to :get, path, 404, "not be found: 999999"
      end

      describe "POST #{opts[:path]}/:invalid_id/" do
        it_responds_to :post, path, 404, /Unknown request/
      end

      describe "PUT #{opts[:path]}/:invalid_id/" do
        it_responds_to :put, path, 404, "not be found: 999999"
      end

      describe "DELETE #{opts[:path]}/:invalid_id/" do
        it_responds_to :delete, path, 404, "not be found: 999999"
      end
    end
  end
end
