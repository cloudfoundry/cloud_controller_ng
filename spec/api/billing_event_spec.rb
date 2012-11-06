# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::BillingEvent do
    describe "permissions" do
      context "with 5 event records" do
        before(:all) do
          Models::BillingEvent.delete
          @org_event = Models::OrganizationStartEvent.make
          @app_start_event = Models::AppStartEvent.make
          @app_stop_event = Models::AppStopEvent.make
          @service_create_event = Models::ServiceCreateEvent.make
          @service_delete_event = Models::ServiceDeleteEvent.make
        end

        describe "GET /v2/billing_events" do
          let(:org) do
            Models::Organization.make
          end

          let(:admin_headers) do
            user = VCAP::CloudController::Models::User.make(:admin => true)
            headers_for(user)
          end

          let(:org_admin_headers) do
            user = Models::User.make
            org.add_user(user)
            org.add_manager(user)
            headers_for(user)
          end

          let(:path) do
            "/v2/billing_events"
          end

          context "as a cf admin" do
            it "should return 200" do
              get path, {}, admin_headers
              last_response.status.should == 200
            end

            it "should return 5 records" do
              get path, {}, admin_headers
              decoded_response["total_results"].should == 5
              decoded_response["total_pages"].should == 1
              decoded_response["prev_url"].should == nil
              decoded_response["next_url"].should == nil
              decoded_response["resources"].size.should == 5
            end

            it "should correctly serialize the org billing start event" do
              get path, {}, admin_headers
              decoded_response["resources"][0].should == {
                "event_type" => "organization_billing_start",
                "organization_id" => @org_event.organization_guid,
                "organization_name" => @org_event.organization_name,
                "timestamp" => @org_event.timestamp.to_s,
              }
            end

            it "should correctly serialize the app start event" do
              get path, {}, admin_headers
              decoded_response["resources"][1].should == {
                "event_type" => "app_start",
                "organization_id" => @app_start_event.organization_guid,
                "organization_name" => @app_start_event.organization_name,
                "space_id" => @app_start_event.space_guid,
                "space_name" => @app_start_event.space_name,
                "app_id" => @app_start_event.app_guid,
                "app_name" => @app_start_event.app_name,
                "app_run_id" => @app_start_event.app_run_id,
                "app_plan_name" => @app_start_event.app_plan_name,
                "app_memory" => @app_start_event.app_memory,
                "app_instance_count" => @app_start_event.app_instance_count,
                "timestamp" => @app_start_event.timestamp.to_s,
              }
            end

            it "should correctly serialize the app stop event" do
              get path, {}, admin_headers
              decoded_response["resources"][2].should == {
                "event_type" => "app_stop",
                "organization_id" => @app_stop_event.organization_guid,
                "organization_name" => @app_stop_event.organization_name,
                "space_id" => @app_stop_event.space_guid,
                "space_name" => @app_stop_event.space_name,
                "app_id" => @app_stop_event.app_guid,
                "app_name" => @app_stop_event.app_name,
                "app_run_id" => @app_stop_event.app_run_id,
                "timestamp" => @app_stop_event.timestamp.to_s,
              }
            end

            it "should correctly serialize the service create event" do
              get path, {}, admin_headers
              decoded_response["resources"][3].should == {
                "event_type" => "service_create",
                "organization_id" => @service_create_event.organization_guid,
                "organization_name" => @service_create_event.organization_name,
                "space_id" => @service_create_event.space_guid,
                "space_name" => @service_create_event.space_name,
                "service_instance_id" => @service_create_event.service_instance_guid,
                "service_instance_name" => @service_create_event.service_instance_name,
                "service_id" => @service_create_event.service_guid,
                "service_label" => @service_create_event.service_label,
                "service_provider" => @service_create_event.service_provider,
                "service_version" => @service_create_event.service_version,
                "service_plan_id" => @service_create_event.service_plan_guid,
                "service_plan_name" => @service_create_event.service_plan_name,
                "timestamp" => @service_create_event.timestamp.to_s,
              }
            end

            it "should correctly serialize the service delete event" do
              get path, {}, admin_headers
              decoded_response["resources"][4].should == {
                "event_type" => "service_delete",
                "organization_id" => @service_delete_event.organization_guid,
                "organization_name" => @service_delete_event.organization_name,
                "space_id" => @service_delete_event.space_guid,
                "space_name" => @service_delete_event.space_name,
                "service_instance_id" => @service_delete_event.service_instance_guid,
                "service_instance_name" => @service_delete_event.service_instance_name,
                "timestamp" => @service_delete_event.timestamp.to_s,
              }
            end
          end

          context "as an org admin" do
            it "should return 200" do
              get path, {}, org_admin_headers
              last_response.status.should == 200
            end

            it "should return 0 records" do
              get path, {}, org_admin_headers
              decoded_response["total_results"].should == 0
              decoded_response["resources"].size.should == 0
            end
          end
        end
      end
    end
  end
end
