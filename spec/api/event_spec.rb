require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Event do
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
  end
end