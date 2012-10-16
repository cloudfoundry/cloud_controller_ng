# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "operations on an invalid object" do |opts|
    describe "operations on an invalid object" do
      describe "POST #{opts[:path]}/:invalid_id/" do
        before(:all) do
          post "#{opts[:path]}/999999", {}, json_headers(admin_headers)
        end

      it "should return 404" do
        last_response.status.should == 404
      end

      it_behaves_like "a vcap rest error response", /Unknown request/
      end

      [:put, :delete, :get].each do |verb|
        describe "#{verb.upcase} #{opts[:path]}/:invalid_id/" do
          before(:all) do
            send(verb, "#{opts[:path]}/999999", {}, json_headers(admin_headers))
          end

        it "should return 404" do
          last_response.status.should == 404
        end

        it_behaves_like "a vcap rest error response", "not be found: 999999"
        end
      end
    end
  end
end
