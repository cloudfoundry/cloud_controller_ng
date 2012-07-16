# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Framework do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/frameworks",
    :model                => VCAP::CloudController::Models::Framework,
    :basic_attributes     => [:name, :description],
    :required_attributes  => [:name, :description],
    :unique_attributes    => :name,
    :one_to_many_collection_ids => {
      :apps  => lambda { |framework| VCAP::CloudController::Models::App.make }
    }
  }

  describe "related permissions" do
    include_context "permissions"
    let(:framework) { Models::Framework.make }

    before do
      3.times { VCAP::CloudController::Models::App.make(:space => @space_a, :framework => framework) }
      2.times { VCAP::CloudController::Models::App.make(:space => @space_b, :framework => framework) }
    end

    describe "GET /v2/frameworks/:guid?inline-relations-depth=1" do
      it "should limit inlined apps those visible to the user making the call" do
        get "/v2/frameworks/#{framework.guid}", { "inline-relations-depth" => 1 }, headers_for(@space_a_developer)
        last_response.should be_ok
        decoded_response["entity"]["apps"].count.should == 3

        get "/v2/frameworks/#{framework.guid}", { "inline-relations-depth" => 1 }, headers_for(@space_b_developer)
        last_response.should be_ok
        decoded_response["entity"]["apps"].count.should == 2
      end
    end

    describe "GET /v2/frameworks/:guid/apps" do
      it "should limit inlined apps those visible to the user making the call" do
        get "/v2/frameworks/#{framework.guid}/apps", {}, headers_for(@space_a_developer)
        last_response.should be_ok
        decoded_response["total_results"].should == 3

        get "/v2/frameworks/#{framework.guid}/apps", {}, headers_for(@space_b_developer)
        last_response.should be_ok
        decoded_response["total_results"].should == 2
      end
    end
  end

end
