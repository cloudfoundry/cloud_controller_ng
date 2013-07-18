# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition do
    include_examples "uaa authenticated api", path: "/v2/quota_definitions"
    include_examples "enumerating objects", path: "/v2/quota_definitions", model: Models::QuotaDefinition
    include_examples "reading a valid object", path: "/v2/quota_definitions", model: Models::QuotaDefinition, basic_attributes: %w(name non_basic_services_allowed total_services memory_limit trial_db_allowed)
    include_examples "operations on an invalid object", path: "/v2/quota_definitions"
    include_examples "creating and updating", path: "/v2/quota_definitions", model: Models::QuotaDefinition, required_attributes: %w(name non_basic_services_allowed total_services memory_limit), unique_attributes: %w(name)
    include_examples "deleting a valid object", path: "/v2/quota_definitions", model: Models::QuotaDefinition, one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {
        :organizations => lambda { |quota_definition|
          Models::Organization.make(:quota_definition => quota_definition)
        }
      }
    include_examples "collection operations", path: "/v2/quota_definitions", model: Models::QuotaDefinition,
      one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {
        organizations: lambda { |quota_definition| Models::Organization.make(quota_definition: quota_definition) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}
  end

  describe "permissions" do
    after(:all) { reset_database }

    let(:quota_attributes) {
      {
        :name => quota_name,
        :non_basic_services_allowed => false,
        :total_services => 1,
        :memory_limit => 1024
      }
    }
    let(:existing_quota) { VCAP::CloudController::Models::QuotaDefinition.make }

    context "when the user is a cf admin" do
      let(:headers) { headers_for(VCAP::CloudController::Models::User.make(:admin => true)) }
      let(:quota_name) { "quota 1" }

      it "does allow creation of a quota def" do
        post "/v2/quota_definitions", Yajl::Encoder.encode(quota_attributes), json_headers(headers)
        last_response.status.should == 201
      end

      it "does allow read of a quota def" do
        get "/v2/quota_definitions/#{existing_quota.guid}", {}, headers
        last_response.status.should == 200
      end

      it "does allow update of a quota def" do
        put "/v2/quota_definitions/#{existing_quota.guid}", Yajl::Encoder.encode({:total_services => 2}), json_headers(headers)
        last_response.status.should == 201
      end

      it "does allow deletion of a quota def" do
        delete "/v2/quota_definitions/#{existing_quota.guid}", {}, headers
        last_response.status.should == 204
      end
    end

    context "when the user is not a cf admin" do
      let(:headers) { headers_for(VCAP::CloudController::Models::User.make(:admin => false)) }
      let(:quota_name) { "quota 2" }

      it "does not allow creation of a quota def" do
        post "/v2/quota_definitions", Yajl::Encoder.encode(quota_attributes), json_headers(headers)
        last_response.status.should == 403
      end

      it "does allow read of a quota def" do
        get "/v2/quota_definitions/#{existing_quota.guid}", {}, headers
        last_response.status.should == 200
      end

      it "does not allow update of a quota def" do
        put "/v2/quota_definitions/#{existing_quota.guid}", Yajl::Encoder.encode(quota_attributes), json_headers(headers)
        last_response.status.should == 403
      end

      it "does not allow deletion of a quota def" do
        delete "/v2/quota_definitions/#{existing_quota.guid}", {}, headers
        last_response.status.should == 403
      end
    end
  end
end
