# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "querying objects" do |opts|
    describe "querying objects" do
      before(:all) { 5.times { opts[:model].make } }

      opts[:queryable_attributes].each do |attr|
        describe "#{opts[:path]}?q=#{attr}:<val>" do
          before(:all) do
            @val = Sham.send(attr)
            opts[:model].make(attr => @val)
          end

          describe "with a matching value" do
            before(:all) do
              get "#{opts[:path]}?q=#{attr}:#{@val}", {}, json_headers(admin_headers)
            end

            it "should return 200" do
              last_response.status.should == 200
            end

            it "should return total_results => 1" do
              decoded_response["total_results"].should == 1
            end
          end

          describe "with a non-existent value" do
            before(:all) do
              @non_existent_value = Sham.send(attr)
              get "#{opts[:path]}?q=#{attr}:#{@non_existent_value}", {}, json_headers(admin_headers)
            end

            it "should return 200" do
              last_response.status.should == 200
            end

            it "should return total_results => 0" do
              decoded_response["total_results"].should == 0
            end
          end
        end
      end
    end
  end
end
