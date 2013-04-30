require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::CrashEvent do
    def get_obj_guid(obj_name)
      self.method(obj_name).call.guid
    end

    def body
      Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
    end

    def total_results
      body[:total_results]
    end

    def result(index)
      body[:resources][index]
    end

    def no_resource_has
      body[:resources].each do |r|
        yield(r).should be_false
      end
    end

    before(:each) { reset_database }

    let(:org) { Models::Organization.make }
    let(:space_a) { Models::Space.make :organization => org }

    let(:space_a_app_obj) { Models::App.make :space => space_a }

    let(:user) { Models::User.make(:admin => true).tap { |u| u.organizations << org } }
    let(:admin_headers) { headers_for(user) }

    let(:base_timestamp)      { Time.now }
    let(:timestamp_one)       { base_timestamp + 100 }
    let(:timestamp_after_one) { base_timestamp + 150 }
    let(:timestamp_two)       { base_timestamp + 200 }
    let(:timestamp_after_two) { base_timestamp + 250 }
    let(:timestamp_three)     { base_timestamp + 300 }

    shared_examples("filtering by time") do |endpoint, obj_name|
      let(:obj_guid) { get_obj_guid(obj_name) }

      let!(:crash_event1) { Models::CrashEvent.make :app => space_a_app_obj, :timestamp => timestamp_one, :exit_description => "Crashed 1" }
      let!(:crash_event2) { Models::CrashEvent.make :app => space_a_app_obj, :timestamp => timestamp_two, :exit_description => "Crashed 2" }
      let!(:crash_event3) { Models::CrashEvent.make :app => space_a_app_obj, :timestamp => timestamp_three, :exit_description => "Crashed 3" }

      it "returns status code 200" do
        get "/v2/#{endpoint}/#{obj_guid}/crash_events?start_date=#{timestamp_after_two.utc.iso8601}", {}, admin_headers
        last_response.status.should == 200
      end

      it "returns crash events after 'start_time' if start_time is specified" do
        get "/v2/#{endpoint}/#{obj_guid}/crash_events?start_date=#{timestamp_after_two.utc.iso8601}", {}, admin_headers
        total_results.should == 1
        result(0)[:exit_description].should == "Crashed 3"
      end

      it "returns crash events before 'end_time' if end_time is specified" do
        get "/v2/#{endpoint}/#{obj_guid}/crash_events?end_date=#{timestamp_after_one.utc.iso8601}", {}, admin_headers
        total_results.should == 1
        result(0)[:exit_description].should == "Crashed 1"
      end

      it "returns crash events between 'start_time' and 'end_time' if both are specified" do
        get "/v2/#{endpoint}/#{obj_guid}/crash_events?start_date=#{base_timestamp.utc.iso8601}&end_date=#{timestamp_after_two.utc.iso8601}", {}, admin_headers
        total_results.should == 2
        result(0)[:exit_description].should == "Crashed 1"
        result(1)[:exit_description].should == "Crashed 2"
      end

      it "returns all crash events if neither are specified" do
        get "/v2/#{endpoint}/#{obj_guid}/crash_events", {}, admin_headers
        total_results.should == 3
        result(0)[:exit_description].should == "Crashed 1"
        result(1)[:exit_description].should == "Crashed 2"
        result(2)[:exit_description].should == "Crashed 3"
      end
    end

    shared_examples("pagination") do
      let(:completely_unrelated_app) { Models::App.make }

      before do
        100.times do |index|
          Models::CrashEvent.make :app => completely_unrelated_app, :exit_description => "Crashed #{index}"
        end
      end

      it "paginates the results" do
        get "/v2/apps/#{completely_unrelated_app.guid}/crash_events", {}, admin_headers
        body[:total_pages].should == 2
        body[:prev_url].should be_nil
        body[:next_url].should == "/v2/apps?page=2&results-per-page=50"
      end
    end


    describe 'GET /v2/apps/:guid/crash_events' do
      include_examples("filtering by time", "apps", :space_a_app_obj)
    end

    describe 'GET /v2/spaces/:guid/crash_events' do
      include_examples("filtering by time", "spaces", :space_a)

      let(:space_a_app_obj2) { Models::App.make :space => space_a }

      let(:space_b) { Models::Space.make :organization => org }
      let(:space_b_app_obj) { Models::App.make :space => space_b }
      let!(:space_b_crash_event) { Models::CrashEvent.make :app => space_b_app_obj, :exit_description => "Space B" }

      it "aggregates over a space" do
        Models::CrashEvent.make :app => space_a_app_obj2, :exit_description => "Other Space A"

        get "/v2/spaces/#{space_a.guid}/crash_events", {}, admin_headers
        total_results.should == 4
        no_resource_has { |r| r[:exit_description] == "Space B" }
      end
    end

    describe 'GET /v2/organizations/:guid/crash_events' do
      include_examples("filtering by time", "organizations", :org)
      include_examples("pagination")

      let!(:org_b_app_obj) { Models::App.make }
      let!(:org_b_crash_event) { Models::CrashEvent.make :app => org_b_app_obj, :exit_description => "Wrong Org" }

      it "aggregates over an org" do
        get "/v2/organizations/#{org.guid}/crash_events", {}, admin_headers
        total_results.should == 3
        no_resource_has { |r| r[:exit_description] == "Wrong Org" }
      end
    end
  end
end