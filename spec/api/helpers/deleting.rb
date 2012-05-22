# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "deleting a valid object" do |opts|
    describe "deleting a valid object" do
      describe "DELETE #{opts[:path]}/:id" do
        let (:obj) { opts[:model].make }

        before do
          delete "#{opts[:path]}/#{obj.id}", {}, admin_headers
        end

        it "should return 204" do
          last_response.status.should == 204
        end

        it "should return an empty response body" do
          last_response.body.should be_empty
        end
      end
    end
  end
end
