require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppEventsController, type: :controller do
    def get_obj_guid(obj_name)
      send(obj_name).guid
    end

    def body
      Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
    end

    def total_results
      body[:total_results]
    end

    def result(index)
      body[:resources][index][:entity]
    end

    def no_resource_has
      body[:resources].each do |r|
        yield(r).should be_false
      end
    end

    let(:org) { Organization.make }
    let(:space_a) { Space.make :organization => org }

    let(:space_a_app_obj) { AppFactory.make :space => space_a }

    let(:user) { User.make(:admin => true).tap { |u| u.organizations << org } }

    let(:base_timestamp)      { Time.now }
    let(:timestamp_one)       { base_timestamp + 100 }
    let(:timestamp_after_one) { base_timestamp + 150 }
    let(:timestamp_two)       { base_timestamp + 200 }
    let(:timestamp_after_two) { base_timestamp + 250 }
    let(:timestamp_three)     { base_timestamp + 300 }

    # ; is %3B
    #
    # < is %3C
    # = is %3D
    # > is %3E
    shared_examples("filtering by time") do |endpoint_pattern, obj_name|
      let!(:app_event1) { AppEvent.make :app => space_a_app_obj, :timestamp => timestamp_one, :exit_description => "Crashed 1" }
      let!(:app_event2) { AppEvent.make :app => space_a_app_obj, :timestamp => timestamp_two, :exit_description => "Crashed 2" }
      let!(:app_event3) { AppEvent.make :app => space_a_app_obj, :timestamp => timestamp_three, :exit_description => "Crashed 3" }

      let(:endpoint) { endpoint_pattern.sub(":guid", get_obj_guid(obj_name)) }

      it "returns status code 200" do
        get "#{endpoint}?q=timestamp%3E%3D#{timestamp_after_two.utc.iso8601}", {}, admin_headers
        last_response.status.should == 200
      end

      it "returns crash events on or after start timestamp if specified" do
        get "#{endpoint}?q=timestamp%3E%3D#{timestamp_after_two.utc.iso8601}", {}, admin_headers
        total_results.should == 1
        result(0)[:exit_description].should == "Crashed 3"
      end

      it "returns crash events on or before end timestamp if specified" do
        get "#{endpoint}?q=timestamp%3C%3D#{timestamp_after_one.utc.iso8601}", {}, admin_headers
        total_results.should == 1
        result(0)[:exit_description].should == "Crashed 1"
      end

      it "returns crash events between start and end timestamps (inclusive) if both are specified" do
        get "#{endpoint}?q=timestamp%3E%3D#{base_timestamp.utc.iso8601}%3Btimestamp%3C%3D#{timestamp_after_two.utc.iso8601}", {}, admin_headers
        total_results.should == 2
        result(0)[:exit_description].should == "Crashed 1"
        result(1)[:exit_description].should == "Crashed 2"
      end

      it "returns all crash events if neither start nor end timestamp is specified" do
        get "#{endpoint}", {}, admin_headers
        total_results.should == 3
        result(0)[:exit_description].should == "Crashed 1"
        result(1)[:exit_description].should == "Crashed 2"
        result(2)[:exit_description].should == "Crashed 3"
      end
    end

    shared_examples("pagination") do
      let(:completely_unrelated_app) { AppFactory.make }

      before do
        100.times do |index|
          AppEvent.make :app => completely_unrelated_app, :exit_description => "Crashed #{index}"
        end
      end

      it "paginates the results" do
        get "/v2/apps/#{completely_unrelated_app.guid}/events", {}, admin_headers
        body[:total_pages].should == 2
        body[:prev_url].should be_nil
        body[:next_url].should == "/v2/apps/#{completely_unrelated_app.guid}/events?order-direction=asc&page=2&results-per-page=50"
      end
    end

    describe 'GET /v2/apps/:guid/events' do
      include_examples("filtering by time", "/v2/apps/:guid/events", :space_a_app_obj)
      include_examples("pagination")
    end

    describe 'GET /v2/spaces/:guid/app_events' do
      include_examples("filtering by time", "/v2/spaces/:guid/app_events", :space_a)
      include_examples("pagination")

      before do
        AppEvent.make(
          :app => AppFactory.make,
          :exit_description => "Wrong Space")
      end

      it "aggregates over a space" do
        get "/v2/spaces/#{space_a.guid}/app_events", {}, admin_headers
        total_results.should == 3
        no_resource_has { |r| r[:exit_description] == "Wrong Space" }
      end
    end

    describe 'GET /v2/organizations/:guid/app_events' do
      include_examples("filtering by time", "/v2/organizations/:guid/app_events", :org)
      include_examples("pagination")

      before do
        AppEvent.make(
          :app => AppFactory.make,
          :exit_description => "Wrong Org")
      end

      it "aggregates over an org" do
        get "/v2/organizations/#{org.guid}/app_events", {}, admin_headers
        total_results.should == 3
        no_resource_has { |r| r[:exit_description] == "Wrong Org" }
      end
    end
  end
end
