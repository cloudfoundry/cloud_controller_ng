# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "deleting a valid object" do |opts|
    describe "deleting a valid object" do
      describe "DELETE #{opts[:path]}/:id" do
        let(:obj) { opts[:model].make }

        subject { delete "#{opts[:path]}/#{obj.guid}", {}, admin_headers }

        context "when there are no child associations" do
          before do
            if obj.is_a? Models::Service
              # Blueprint makes a ServiceAuthToken. No other model has child associated models created by Blueprint.
              obj.service_auth_token.delete
            end
          end

          it "should return 204" do
            subject
            last_response.status.should == 204
          end

          it "should return an empty response body" do
            subject
            last_response.body.should be_empty
          end
        end

        context "when the object has a child associations" do
          let(:one_to_one_or_many) do
            obj.class.associations.select do |association|
              [:one_to_many, :one_to_one].include?(obj.class.association_reflection(association)[:type])
            end
          end

          before do
            opts[:one_to_many_collection_ids_without_url].each { |_, child| child.call(obj) }
            opts[:one_to_many_collection_ids].each { |_, child| child.call(obj) }
          end

          around { |example| example.call unless one_to_one_or_many.empty? }

          it "should return 400" do
            subject
            last_response.status.should == 400
          end

          it "should return the expected response body" do
            subject
            Yajl::Parser.parse(last_response.body).should == {
                "code" => 10006,
                "description" => "Please delete the #{one_to_one_or_many.join(", ")} associations for your #{obj.class.table_name}.",
            }
          end
        end
      end
    end
  end
end
