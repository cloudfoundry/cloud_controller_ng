require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  # port of the legacy cc info spec, minus legacy token support. i.e. this is jwt
  # tokens only.
  describe VCAP::CloudController::LegacyInfo do
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
        let(:current_user) { make_user_with_default_space(:admin => true) }

        it "should return admin limits for an admin" do
          get "/info", {}, headers
          last_response.status.should == 200
          hash = Yajl::Parser.parse(last_response.body)
          hash.should have_key("limits")
          hash["limits"].should == {
            "memory"   => AccountCapacity::ADMIN_MEM,
            "app_uris" => AccountCapacity::ADMIN_URIS,
            "services" => AccountCapacity::ADMIN_SERVICES,
            "apps"     => AccountCapacity::ADMIN_APPS
          }
        end
      end

      describe "for a user" do
        let(:current_user) { make_user_with_default_space }

        it "should return default limits for a user" do
          get "/info", {}, headers
          last_response.status.should == 200
          hash = Yajl::Parser.parse(last_response.body)
          hash.should have_key("limits")
          hash["limits"].should == {
            "memory"   => AccountCapacity::DEFAULT_MEM,
            "app_uris" => AccountCapacity::DEFAULT_URIS,
            "services" => AccountCapacity::DEFAULT_SERVICES,
            "apps"     => AccountCapacity::DEFAULT_APPS
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
              Models::App.make(:space => current_user.default_space,
                               :state => "STARTED", :instances => 2, :memory => 128)
            end

            5.times do
              Models::App.make(:space => current_user.default_space,
                               :state => "STOPPED", :instances => 2, :memory => 128)
            end

            3.times do
              Models::ServiceInstance.make(:space => current_user.default_space)
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

    describe "service info" do
      before do
        @mysql_svc  = Models::Service.make(
          :label => "mysql",
          :provider => "core",
        )
        @pg_svc     = Models::Service.make(
          :label => "postgresql",
          :provider => "core",
        )
        @redis_svc  = Models::Service.make(
          :label => "redis",
          :provider => "core",
        )
        @mongo_svc  = Models::Service.make(
          :label => "mongodb",
          :provider => "core",
        )
        @random_svc = Models::Service.make(
          :label => "random",
          :provider => "core",
        )
        non_core = Models::Service.make

        get "/info/services", {}, headers_for(Models::User.make)
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should return synthesized types as the top level key" do
        hash = Yajl::Parser.parse(last_response.body)
        hash.should have_key("database")
        hash.should have_key("key-value")
        hash.should have_key("generic")

        hash["database"].length.should == 2
        hash["key-value"].length.should == 2
        hash["generic"].length.should == 1
      end

      it "should return mysql as a database" do
        hash = Yajl::Parser.parse(last_response.body)
        hash["database"].should have_key("mysql")
        hash["database"]["mysql"].should == {
          @mysql_svc.version => {
            "id" => @mysql_svc.guid,
            "vendor" => "mysql",
            "version" => @mysql_svc.version,
            "type" => "database",
            "description" => @mysql_svc.description,
            "tiers" => {
              "free" => {
                "options" =>{},
                "order" => 1
              }
            }
          }
        }
      end

      it "should return pg as a database" do
        hash = Yajl::Parser.parse(last_response.body)
        hash["database"].should have_key("postgresql")
        hash["database"]["postgresql"].should == {
          @pg_svc.version => {
            "id" => @pg_svc.guid,
            "vendor" => "postgresql",
            "version" => @pg_svc.version,
            "type" => "database",
            "description" => @pg_svc.description,
            "tiers" => {
              "free" => {
                "options" =>{},
                "order" => 1
              }
            }
          }
        }
      end

      it "should return redis under key-value" do
        hash = Yajl::Parser.parse(last_response.body)
        hash["key-value"].should have_key("redis")
        hash["key-value"]["redis"].should == {
          @redis_svc.version => {
            "id" => @redis_svc.guid,
            "vendor" => "redis",
            "version" => @redis_svc.version,
            "type" => "key-value",
            "description" => @redis_svc.description,
            "tiers" => {
              "free" => {
                "options" =>{},
                "order" => 1
              }
            }
          }
        }
      end

      it "should (incorrectly) return mongo under key-value" do
        hash = Yajl::Parser.parse(last_response.body)
        hash["key-value"].should have_key("mongodb")
        hash["key-value"]["mongodb"].should == {
          @mongo_svc.version => {
            "id" => @mongo_svc.guid,
            "vendor" => "mongodb",
            "version" => @mongo_svc.version,
            "type" => "key-value",
            "description" => @mongo_svc.description,
            "tiers" => {
              "free" => {
                "options" =>{},
                "order" => 1
              }
            }
          }
        }
      end

      it "should return random under generic" do
        hash = Yajl::Parser.parse(last_response.body)
        hash["generic"].should have_key("random")
        hash["generic"]["random"].should == {
          @random_svc.version => {
            "id" => @random_svc.guid,
            "vendor" => "random",
            "version" => @random_svc.version,
            "type" => "generic",
            "description" => @random_svc.description,
            "tiers" => {
              "free" => {
                "options" =>{},
                "order" => 1
              }
            }
          }
        }
      end
    end
  end
end
