require File.expand_path("../spec_helper", __FILE__)

# port of the legacy cc info spec, minus legacy token support. i.e. this is jwt
# tokens only.
describe VCAP::CloudController::LegacyInfo do
  def create_user(admin)
    user = Models::User.make(:admin => admin,  :active => true)
    app_space = Models::AppSpace.make
    app_space.organization.add_user(user)
    app_space.add_developer(user)
    user.default_app_space = app_space
    user
  end

  shared_examples "legacy info response" do |expected_status, expect_user|
    it "should return #{expected_status}" do
      last_response.status.should == expected_status
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

  VCAP::CloudController::ApiSpecHelper::HTTPS_ENFORCEMENT_SCENARIOS.each do |scenario_vars|
    config_setting = scenario_vars[:config_setting]
    config_desc = config_setting ? "with #{config_setting} enabled" : ""
    protocol = scenario_vars[:protocol]
    expected_status = scenario_vars[:success] ? 200 : 403

    describe "#{config_desc} using #{protocol}" do
      let(:current_user) do
        case scenario_vars[:user]
        when "admin"
          create_user(true)
        when "user"
          create_user(false)
        end
      end

      let(:headers) { headers_for(current_user, nil, scenario_vars[:protocol] == "https") }

      before do
        config_override(config_setting => true)
      end

      context "with invalid authorization header for #{scenario_vars[:user]}" do
        before do
          headers["HTTP_AUTHORIZATION"].reverse! if headers["HTTP_AUTHORIZATION"]
          get "/info", {}, headers
        end

        include_examples "legacy info response", 200, false
      end

      context "with a valid authorization header for #{scenario_vars[:user]}" do
        before do
          get "/info", {}, headers
        end

        include_examples "legacy info response", expected_status, scenario_vars[:success]
      end
    end
  end

  describe "account capacity" do
    let(:headers) { headers_for(current_user) }

    describe "for an amdin" do
      let(:current_user) { create_user(true) }

      it "should return admin limits for an admin" do
        get "/info", {}, headers
        last_response.status.should == 200
        hash = Yajl::Parser.parse(last_response.body)
        hash.should have_key("limits")
        hash["limits"].should == {
          "memory"   => Models::AccountCapacity::ADMIN_MEM,
          "app_uris" => Models::AccountCapacity::ADMIN_URIS,
          "services" => Models::AccountCapacity::ADMIN_SERVICES,
          "apps"     => Models::AccountCapacity::ADMIN_APPS
        }
      end
    end

    describe "for a user" do
      let(:current_user) { create_user(false) }

      it "should return default limits for a user" do
        get "/info", {}, headers
        last_response.status.should == 200
        hash = Yajl::Parser.parse(last_response.body)
        hash.should have_key("limits")
        hash["limits"].should == {
          "memory"   => Models::AccountCapacity::DEFAULT_MEM,
          "app_uris" => Models::AccountCapacity::DEFAULT_URIS,
          "services" => Models::AccountCapacity::DEFAULT_SERVICES,
          "apps"     => Models::AccountCapacity::DEFAULT_APPS
        }
      end

      context "with no apps and services" do
       it "should return 0 apps and service usage" do
          get "/info", {}, headers
          last_response.status.should == 200
          hash = Yajl::Parser.parse(last_response.body)
          hash.should have_key("usage")

          hash["usage"].should == {
            "memory"   => 0,
            "apps"     => 0,
            "services" => 0
          }
        end
      end

      context "with 2 started apps with 2 instances, 5 stopped apps, and 3 service" do
        before do
          2.times do
            Models::App.make(:app_space => current_user.default_app_space,
                             :state => "STARTED", :instances => 2, :memory => 128)
          end

          5.times do
            Models::App.make(:app_space => current_user.default_app_space,
                             :state => "STOPPED", :instances => 2, :memory => 128)
          end

          3.times do
            Models::ServiceInstance.make(:app_space => current_user.default_app_space)
          end
        end

        it "should return 2 apps and 3 services" do
          get "/info", {}, headers
          last_response.status.should == 200
          hash = Yajl::Parser.parse(last_response.body)
          hash.should have_key("usage")

          hash["usage"].should == {
            "memory"   => 128 * 4,
            "apps"     => 2,
            "services" => 3
          }
        end
      end
    end
  end
end
