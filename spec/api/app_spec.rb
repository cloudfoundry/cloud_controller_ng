# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::App do
  let(:app_obj) { VCAP::CloudController::Models::App.make }
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }
  let(:runtime) { VCAP::CloudController::Models::Runtime.make }
  let(:framework) { VCAP::CloudController::Models::Framework.make }

  # FIXME: make app_space_id a relation check that checks the id and the url
  # part.  do everywhere
  it_behaves_like "a CloudController API", {
    :path                => "/v2/apps",
    :model               => VCAP::CloudController::Models::App,
    :basic_attributes    => [:name, :app_space_guid, :runtime_guid, :framework_guid],
    :required_attributes => [:name, :app_space_guid, :runtime_guid, :framework_guid],
    :unique_attributes   => [:name, :app_space_guid],

    :many_to_one_collection_ids => {
      :app_space       => lambda { |app| VCAP::CloudController::Models::AppSpace.make  },
      :framework       => lambda { |app| VCAP::CloudController::Models::Framework.make },
      :runtime         => lambda { |app| VCAP::CloudController::Models::Runtime.make   }
    },
    :one_to_many_collection_ids  => {
      :service_bindings   =>
       lambda { |app|
          service_binding = VCAP::CloudController::Models::ServiceBinding.make
          service_binding.service_instance.app_space = app.app_space
          service_binding
       }
    }
  }

  describe "validations" do
    let(:app_obj)   { VCAP::CloudController::Models::App.make }
    let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

    let(:admin_headers) do
      user = VCAP::CloudController::Models::User.make(:admin => true)
      headers_for(user)
    end

    describe "env" do
      it "should allow an empty environment" do
        hash = {}
        update_hash = { :environment_json => hash }

        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
        last_response.status.should == 201
      end

      it "should allow multiple variables" do
        hash = { :abc => 123, :def => "hi" }
        update_hash = { :environment_json => hash }
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
        last_response.status.should == 201
      end

      [ "VMC", "vmc", "VCAP", "vcap" ].each do |k|
        it "should not allow entries to start with #{k}" do
          hash = { :abc => 123, "#{k}_abc" => "hi" }
          update_hash = { :environment_json => hash }
          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
          last_response.status.should == 400
          decoded_response["description"].should match /environment_json reserved_key:#{k}_abc/
        end
      end
    end
  end

  describe "quota" do
    let(:cf_admin) { Models::User.make(:admin => true) }
    let(:app_obj) { Models::App.make }

    describe "create" do
      it "should fetch a quota token" do
        RestController::QuotaManager.should_not_receive(:fetch_quota_token).with(nil)
        RestController::QuotaManager.should_receive(:fetch_quota_token).once
        post "/v2/apps", Yajl::Encoder.encode(:name => Sham.name,
                                              :app_space_guid => app_obj.app_space_guid,
                                              :framework_guid => app_obj.framework_guid,
                                              :runtime_guid => app_obj.runtime_guid),
                                              headers_for(cf_admin)
      end
    end

    describe "get" do
      it "should not fetch a quota token" do
        RestController::QuotaManager.should_not_receive(:fetch_quota_token)
        get "/v2/apps/#{app_obj.guid}", {}, headers_for(cf_admin)
      end
    end

    describe "update" do
      it "should fetch a quota token" do
        RestController::QuotaManager.should_not_receive(:fetch_quota_token).with(nil)
        RestController::QuotaManager.should_receive(:fetch_quota_token).once
        put "/v2/apps/#{app_obj.guid}",
            Yajl::Encoder.encode(:name => "#{app_obj.name}_renamed"),
            headers_for(cf_admin)
      end
    end

    describe "delete" do
      it "should not fetch a quota token" do
        RestController::QuotaManager.should_not_receive(:fetch_quota_token)
        delete "/v2/apps/#{app_obj.guid}", {}, headers_for(cf_admin)
      end
    end
  end
end
