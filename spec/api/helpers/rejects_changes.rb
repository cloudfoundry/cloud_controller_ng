# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "rejects changes" do |opts|
    describe "rejects changes" do
      def self.it_responds_unknown_request
        it "returns 404" do
          last_response.status.should == 404
        end

        it_behaves_like "a vcap rest error response", /Unknown request/
      end

      define_method :obj do
        @obj ||= opts[:model].make
      end

      describe "POST #{opts[:path]}" do
        before(:all) { post(opts[:path], {}, json_headers(admin_headers)) }
        it_responds_unknown_request
      end

      describe "PUT #{opts[:path]}/:id" do
        before(:all) { put("#{opts[:path]}/#{obj.guid}", {}, json_headers(admin_headers)) }
        it_responds_unknown_request
      end

      describe "DELETE #{opts[:path]}/:id" do
        before(:all) { delete("#{opts[:path]}/#{obj.guid}", {}, json_headers(admin_headers)) }
        it_responds_unknown_request
      end
    end
  end
end