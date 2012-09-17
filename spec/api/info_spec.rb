# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Info do
    shared_examples "info response" do |expected_status, expect_user|
      it "should return #{expected_status}" do
        last_response.status.should == expected_status
      end

      if expected_status == 200
        it "should return an api_version" do
          hash = Yajl::Parser.parse(last_response.body)
          hash.should have_key("api_version")
        end
      end

      if expect_user
        it "should return a 'user' entry" do
          hash = Yajl::Parser.parse(last_response.body)
          hash.should have_key("user")
        end
      else
        it "should not return a 'user' entry" do
          hash = Yajl::Parser.parse(last_response.body)
          hash.should_not have_key("user")
        end
      end
    end

    describe "GET /v2/info" do
      ApiSpecHelper::HTTPS_ENFORCEMENT_SCENARIOS.each do |scenario_vars|
        config_setting = scenario_vars[:config_setting]
        config_desc = config_setting ? "with #{config_setting} enabled" : ""
        protocol = scenario_vars[:protocol]
        expected_status = scenario_vars[:success] ? 200 : 403

        describe "#{config_desc} using #{protocol}" do
          let(:current_user) do
            case scenario_vars[:user]
            when "admin"
              make_user_with_default_space(:admin => true)
            when "user"
              make_user_with_default_space
            end
          end

          let(:headers) { headers_for(current_user, nil, scenario_vars[:protocol] == "https") }

          before do
            config_override(config_setting => true)
          end

          context "with invalid authorization header for #{scenario_vars[:user]}" do
            before do
              headers["HTTP_AUTHORIZATION"].reverse! if headers["HTTP_AUTHORIZATION"]
              get "/v2/info", {}, headers
            end

            include_examples "info response", 200, false
          end

          context "with a valid authorization header for #{scenario_vars[:user]}" do
            before do
              get "/v2/info", {}, headers
            end

            include_examples "info response", expected_status, scenario_vars[:success]
          end
        end
      end
    end
  end
end
