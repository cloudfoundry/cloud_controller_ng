require "spec_helper"

module VCAP::CloudController
  describe EventsController, type: :controller do
    before { reset_database }

    let(:admin_user) { Models::User.make :admin => true }

    describe "GET /v2/events" do
      before do
        @user_a = Models::User.make
        @user_b = Models::User.make

        @org_a = Models::Organization.make
        @org_b = Models::Organization.make

        @space_a = Models::Space.make :organization => @org_a
        @space_b = Models::Space.make :organization => @org_b

        @org_a.add_user(@user_a)
        @org_b.add_user(@user_b)

        @event_a = Models::Event.make :space => @space_a
        @event_b = Models::Event.make :space => @space_b
      end

      context "as an admin" do
        it "includes all events" do
          get "/v2/events", {}, headers_for(admin_user)

          parsed_body = Yajl::Parser.parse(last_response.body)
          parsed_body["total_results"].should == 2
        end
      end

      context "as an auditor" do
        before do
          @space_a.add_auditor(@user_a)
          @space_b.add_auditor(@user_b)
        end

        it "includes only events from space visible to the user" do
          get "/v2/events", {}, headers_for(@user_a)

          parsed_body = Yajl::Parser.parse(last_response.body)
          parsed_body["total_results"].should == 1
        end
      end

      context "as a developer" do
        before do
          @space_a.add_developer(@user_a)
          @space_b.add_developer(@user_b)
        end

        it "includes only events from space visible to the user" do
          get "/v2/events", {}, headers_for(@user_a)

          parsed_body = Yajl::Parser.parse(last_response.body)
          parsed_body["total_results"].should == 1
        end
      end

      describe "GET /v2/spaces/:guid/events" do
        context "as an auditor" do
          before do
            @space_a.add_auditor(@user_a)
          end

          it "includes events belonging to the space" do
            get "/v2/spaces/#{@space_a.guid}/events", {}, headers_for(@user_a)

            parsed_body = Yajl::Parser.parse(last_response.body)
            parsed_body["total_results"].should == 1
          end
        end

        context "as a developer" do
          before do
            @space_a.add_developer(@user_a)
          end

          it "includes events belonging to the space" do
            get "/v2/spaces/#{@space_a.guid}/events", {}, headers_for(@user_a)

            parsed_body = Yajl::Parser.parse(last_response.body)
            parsed_body["total_results"].should == 1
          end
        end

        context "as an other user" do
          it "returns a 403 error" do
            get "/v2/spaces/#{@space_a.guid}/events", {}, headers_for(@user_a)

            last_response.status.should == 403
          end
        end
      end

      describe "GET /v2/events/:guid" do
        context "when the guid is valid" do
          context "and the event is visible to the user" do
            before do
              @space_a.add_auditor(@user_a)
              @space_b.add_auditor(@user_b)
            end

            it "returns the correct event" do
              get "/v2/events/#{@event_a.guid}", {},
                  headers_for(@user_a)

              last_response.status.should == 200

              parsed_body = Yajl::Parser.parse(last_response.body)
              expect(parsed_body["entity"]["actor"]).to eq(@event_a.actor)
              expect(parsed_body["entity"]["actor_type"]).to eq(@event_a.actor_type)
              expect(parsed_body["entity"]["actee"]).to eq(@event_a.actee)
              expect(parsed_body["entity"]["actee_type"]).to eq(@event_a.actee_type)
            end
          end

          context "and the event is NOT visible to the user" do
            it "returns a 403 error" do
              get "/v2/events/#{@event_a.guid}", {},
                  headers_for(@user_b)

              last_response.status.should == 403
            end
          end
        end

        context "when the guid is invalid" do
          it "returns a 404 error" do
            get "/v2/events/some-bogus-guid", {},
                headers_for(admin_user)

            last_response.status.should == 404
          end
        end
      end
    end

    describe "pagination" do
      before do
        100.times do |_|
          Models::Event.make
        end
      end

      it "paginates the results" do
        get "/v2/events", {}, admin_headers
        decoded_response["total_pages"].should == 2
        decoded_response["prev_url"].should be_nil
        decoded_response["next_url"].should == "/v2/events?page=2&results-per-page=50"
      end
    end

    describe "pagination + filtering" do
      let (:base_timestamp) {Time.new}

      before do
        150.times do |i|
          Models::Event.make(timestamp:base_timestamp + i)
        end
      end

      it "paginates the results" do
        get "/v2/events?q=timestamp%3E#{(base_timestamp + 50).utc.iso8601}", {}, admin_headers
        decoded_response["total_pages"].should == 2
        decoded_response["prev_url"].should be_nil
        decoded_response["next_url"].should == "/v2/events?q=timestamp>#{(base_timestamp + 50).utc.iso8601}&page=2&results-per-page=50"
      end
    end

    describe "GET /v2/events/ filtering by event type" do
      let!(:update_event) { Models::Event.make type: "audit.app.update" }
      let!(:crash_event) { Models::Event.make type: "app.crash" }

      it "returns a 200 status code" do
        get "/v2/events?q=type:audit.app.update", {}, headers_for(admin_user)
        last_response.status.should == 200
      end

      context "when passed one type" do
        it "should return events of that type" do
          get "/v2/events?q=type:audit.app.update", {}, headers_for(admin_user)
          decoded_response["total_results"].should == 1
          decoded_response["resources"][0]["metadata"]["guid"].should == update_event.guid
        end
      end

      context "when passed multiple types" do
        it "should return events for matching all the types" do
          get "/v2/events?q=type%20IN%20audit.app.update,app.crash", {}, headers_for(admin_user)
          decoded_response["total_results"].should == 2
          decoded_response["resources"][0]["metadata"]["guid"].should == update_event.guid
          decoded_response["resources"][1]["metadata"]["guid"].should == crash_event.guid
        end
      end

      context "when passed an unknown type" do
        it "should succeed and return no events" do
          get "/v2/events?q=type:audit.app.slartibartfast", {}, headers_for(admin_user)
          last_response.status.should == 200
          decoded_response["total_results"].should == 0
        end
      end
    end

    describe "GET /v2/events/ filtering by both type and time" do
      let(:base_timestamp) { Time.now }
      let(:timestamp_delta) { 100 }
      let(:timestamp_one) { base_timestamp + timestamp_delta }
      let(:timestamp_two) { timestamp_one + timestamp_delta }
      let(:timestamp_three) { timestamp_two + timestamp_delta }

      let(:lte) { "%3C%3D" } #<=
      let(:gte) { "%3E%3D" } #>=
      let(:lt) { "%3C" } #<
      let(:gt) { "%3E" } #>
      let(:semi) { "%3B" } #;

      let!(:event1) { Models::Event.make :timestamp => timestamp_one, type: "audit.app.update" }
      let!(:event2) { Models::Event.make :timestamp => timestamp_two , type: "app.crash"}
      let!(:event3) { Models::Event.make :timestamp => timestamp_three, type: "audit.app.create" }

      it "returns events within a timerange and type set" do
        get "/v2/events?q=timestamp#{gte}#{(timestamp_two).utc.iso8601}#{semi}timestamp#{lt}#{(timestamp_three+1).utc.iso8601}#{semi}type%20IN%20audit.app.update,app.crash",
            {}, headers_for(admin_user)
        decoded_response["total_results"].should == 1
        decoded_response["resources"][0]["metadata"]["guid"].should == event2.guid
      end
    end

    describe "GET /v2/events/ filtering by time" do
      let(:base_timestamp) { Time.now }
      let(:timestamp_delta) { 100 }
      let(:timestamp_one) { base_timestamp + timestamp_delta }
      let(:timestamp_two) { timestamp_one + timestamp_delta }
      let(:timestamp_three) { timestamp_two + timestamp_delta }

      let(:lte) { "%3C%3D" } #<=
      let(:gte) { "%3E%3D" } #>=
      let(:lt) { "%3C" } #<
      let(:gt) { "%3E" } #>
      let(:semi) { "%3B" } #;

      let!(:event1) { Models::Event.make :timestamp => timestamp_one }
      let!(:event2) { Models::Event.make :timestamp => timestamp_two }
      let!(:event3) { Models::Event.make :timestamp => timestamp_three }

      it "returns a 200 status code" do
        get "/v2/events?q=timestamp#{gte}#{base_timestamp.utc.iso8601}", {}, headers_for(admin_user)
        last_response.status.should == 200
      end

      it "returns events on or after (>=) the timestamp" do
        get "/v2/events?q=timestamp#{gte}#{(timestamp_one).utc.iso8601}", {}, headers_for(admin_user)
        decoded_response["total_results"].should == 3
        decoded_response["resources"][0]["metadata"]["guid"].should == event1.guid
        decoded_response["resources"][1]["metadata"]["guid"].should == event2.guid
        decoded_response["resources"][2]["metadata"]["guid"].should == event3.guid
      end

      it "returns events after (>) the timestamp" do
        pending "This actually is a bug in Sequel as far as we can tell.  timestamp>X actually behaves like timestamp>=X"
        get "/v2/events?q=timestamp#{gt}#{(timestamp_one).utc.iso8601}", {}, headers_for(admin_user)
        decoded_response["total_results"].should == 1
        decoded_response["resources"][0]["metadata"]["guid"].should == event2.guid
      end

      it "returns events before (<=) the timestamp" do
        get "/v2/events?q=timestamp#{lte}#{(timestamp_one + timestamp_delta / 2).utc.iso8601}", {}, headers_for(admin_user)
        decoded_response["total_results"].should == 1
        decoded_response["resources"][0]["metadata"]["guid"].should == event1.guid
      end

      it "returns events before (<) the timestamp" do
        get "/v2/events?q=timestamp#{lt}#{timestamp_two.utc.iso8601}", {}, headers_for(admin_user)
        decoded_response["total_results"].should == 1
        decoded_response["resources"][0]["metadata"]["guid"].should == event1.guid
      end

      it "returns events on or before (<=) the timestamp" do
        pending "This actually is a bug in Sequel as far as we can tell.  timestamp<=X actually behaves like timestamp<X"
        get "/v2/events?q=timestamp#{lte}#{timestamp_two.utc.iso8601}", {}, headers_for(admin_user)
        decoded_response["total_results"].should == 2
        decoded_response["resources"][0]["metadata"]["guid"].should == event1.guid
        decoded_response["resources"][1]["metadata"]["guid"].should == event2.guid
      end

      it "returns events within a timerange" do
        get "/v2/events?q=timestamp#{gte}#{(timestamp_one).utc.iso8601}#{semi}timestamp#{lt}#{timestamp_three.utc.iso8601}", {}, headers_for(admin_user)
        decoded_response["total_results"].should == 2
        decoded_response["resources"][0]["metadata"]["guid"].should == event1.guid
        decoded_response["resources"][1]["metadata"]["guid"].should == event2.guid
      end
    end
  end
end