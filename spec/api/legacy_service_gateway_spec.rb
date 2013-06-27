require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::LegacyServiceGateway do
    describe "Gateway facing apis" do
      let(:mock_client) { double(:gw_client) }

      def build_offering(attrs={})
        defaults = {
          :label => "foobar-1.0",
          :url   => "https://www.google.com",
          :supported_versions => ["1.0", "2.0"],
          :version_aliases => {"current" => "2.0"},
          :description => "the foobar svc",
        }
        VCAP::Services::Api::ServiceOfferingRequest.new(defaults.merge(attrs))
      end

      before do
        reset_database

        mock_client.stub(:provision).and_return(
          VCAP::Services::Api::GatewayHandleResponse.new(
            :service_id => "gw_id",
            :configuration => "abc",
            :credentials => { :password => "foo" }
          )
        )
        mock_client.stub(:unprovision)
        mock_client.stub(:unbind)
        Models::ManagedServiceInstance.any_instance.stub(:service_gateway_client).and_return(mock_client)
        Models::ManagedServiceInstance.any_instance.stub(:client).and_return(mock_client)
      end

      describe "POST services/v1/offerings" do
        let(:path) { "services/v1/offerings" }

        let(:auth_header) do
          Models::ServiceAuthToken.create(
            :label    => "foobar",
            :provider => "core",
            :token    => "foobar",
          )

          { "HTTP_X_VCAP_SERVICE_TOKEN" => "foobar" }
        end

        let(:foo_bar_dash_offering) do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => "foo-bar-1.0",
            :url   => "https://www.google.com",
            :supported_versions => ["1.0", "2.0"],
            :version_aliases => {"current" => "2.0"},
            :description => "the foobar svc")
        end

        it "should reject requests without auth tokens" do
          post path, build_offering.encode, {}
          last_response.status.should == 403
        end

        it "should should reject posts with malformed bodies" do
          post path, Yajl::Encoder.encode(:bla => "foobar"), auth_header
          last_response.status.should == 400
        end

        it "should reject requests with missing parameters" do
          msg = { :label => "foobar-2.2",
                  :description => "the foobar svc" }
          post path, Yajl::Encoder.encode(msg), auth_header
          last_response.status.should == 400
        end

        it "should reject requests with invalid parameters" do
          msg = { :label => "foobar-2.2",
                  :description => "the foobar svc",
                  :url => "zazzle" }
          post path, Yajl::Encoder.encode(msg), auth_header
          last_response.status.should == 400
        end

        it "should reject requests with extra dash in label" do
          post path, foo_bar_dash_offering.encode, auth_header
          last_response.status.should == 400
        end

        it "should create service offerings for label/provider services and generate a unique_id" do
          post path, build_offering.encode, auth_header
          last_response.status.should == 200
          svc = Models::Service.find(:label => "foobar", :provider => "core")
          svc.should_not be_nil
          svc.version.should == "2.0"
          svc.unique_id.should == "core_foobar"
        end

        it "should create services with 'extra' data" do
          extra_data = "{\"I\": \"am json #{'more' * 100}\"}"
          o = build_offering
          o.extra = extra_data
          post path, o.encode, auth_header

          last_response.status.should == 200
          service = Models::Service[:label => "foobar", :provider => "core"]
          service.extra.should == extra_data
        end

        shared_examples_for "offering containing service plans" do
          it "should create service plans" do
            post path, both_plans.encode, auth_header

            service = Models::Service[:label => "foobar", :provider => "core"]
            service.service_plans.map(&:name).should include("free", "nonfree")
          end

          it "should update service plans" do
            post path, just_free_plan.encode, auth_header
            post path, both_plans.encode, auth_header

            service = Models::Service[:label => "foobar", :provider => "core"]
            service.service_plans.map(&:name).should include("free", "nonfree")
          end

          it "should remove plans not posted" do
            post path, both_plans.encode, auth_header
            post path, just_free_plan.encode, auth_header

            service = Models::Service[:label => "foobar", :provider => "core"]
            service.service_plans.map(&:name).should == ["free"]
          end
        end

        context "using the deprecated 'plans' key" do
          it_behaves_like "offering containing service plans" do
            let(:just_free_plan) { build_offering(plans: %w[free]) }
            let(:both_plans)     { build_offering(plans: %w[free nonfree]) }
          end
        end

        context "using the 'plan_details' key" do
          let(:just_free_plan) { build_offering(plan_details: [{"name" => "free", "free" => true}]) }
          let(:both_plans) {
            build_offering(
              plan_details: [
                {"name" => "free",    "free" => true},
                {"name" => "nonfree", "free" => false},
              ]
            )
          }

          it_behaves_like "offering containing service plans"

          it "puts the details into the db" do
            offer = build_offering(
              plan_details: [
                {
                  "name"        => "freeplan",
                  "free"        => true,
                  "description" => "free plan",
                  "extra"       => "extra info",
                }
              ]
            )
            post path, offer.encode, auth_header
            last_response.status.should == 200

            service = Models::Service[:label => "foobar", :provider => "core"]
            service.service_plans.should have(1).entries
            service.service_plans.first.description.should == "free plan"
            service.service_plans.first.name.should == "freeplan"
            service.service_plans.first.free.should == true
            service.service_plans.first.extra.should == "extra info"
          end

          it "does not add plans with identical names but different freeness under the same service" do
            post path, just_free_plan.encode, auth_header
            last_response.status.should == 200

            offer2 = build_offering(plan_details: [{"name" => "free", "free" => false, "description" => "tetris"}])
            post path, offer2.encode, auth_header
            last_response.status.should == 200

            service = Models::Service[:label => "foobar", :provider => "core"]
            service.should have(1).service_plans
            service.service_plans.first.description.should == "tetris"
            service.service_plans.first.free.should == false
          end

          it "prevents the request from setting the plan guid" do
            offer = build_offering(
              plan_details:[{"name" => "plan name", "free" => true, "guid" => "myguid"}]
            )
            post path, offer.encode, auth_header
            last_response.status.should == 200

            service = Models::Service[:label => "foobar", :provider => "core"]
            service.should have(1).service_plans
            service.service_plans.first.guid.should_not == "myguid"
          end
        end

        context "using both the 'plan_details' key and the deprecated 'plans' key" do
          it_behaves_like "offering containing service plans" do
            let(:just_free_plan) {
              build_offering(
                plan_details: [{"name" => "free", "free" => true}],
                plans: %w[free],
              )
            }

            let(:both_plans) {
              build_offering(
                plan_details: [
                  {"name" => "free",    "free" => true},
                  {"name" => "nonfree", "free" => false},
                ],
                plans: %w[free nonfree],
              )
            }
          end
        end

        it "should update service offerings for label/provider services" do
          post path, build_offering.encode, auth_header
          offer = build_offering
          offer.url = "http://newurl.com"
          post path, offer.encode, auth_header
          last_response.status.should == 200
          svc = Models::Service.find(:label => "foobar", :provider => "core")
          svc.should_not be_nil
          svc.url.should == "http://newurl.com"
        end
      end

      describe "GET services/v1/offerings/:label_and_version(/:provider)" do
        before :each do
          @svc1 = Models::Service.make(
            :label => "foobar",
            :url => "http://www.google.com",
            :provider => "core",
          )
          Models::ServicePlan.make(
            :name => "free",
            :service => @svc1,
          )
          Models::ServicePlan.make(
            :name => "nonfree",
            :service => @svc1,
          )
          @svc2 = Models::Service.make(
            :label => "foobar",
            :url => "http://www.google.com",
            :provider => "test",
          )
          Models::ServicePlan.make(
            :name => "free",
            :service => @svc2,
          )
          Models::ServicePlan.make(
            :name => "nonfree",
            :service => @svc2,
          )
        end

        let(:auth_header) { {"HTTP_X_VCAP_SERVICE_TOKEN" => @svc1.service_auth_token.token} }

        it "should return not found for unknown label services" do
          get "services/v1/offerings/xxx", {}, auth_header
          # FIXME: should this be 404?
          last_response.status.should == 403
        end

        it "should return not found for unknown provider services" do
          get "services/v1/offerings/foobar-version/xxx", {}, auth_header
          # FIXME: should this be 404?
          last_response.status.should == 403
        end

        it "should return not authorized on token mismatch" do
          get "services/v1/offerings/foobar-version", {}, {
            "HTTP_X_VCAP_SERVICE_TOKEN" => "xxx",
          }
          last_response.status.should == 403
        end

        it "should return the specific service offering which has null provider" do
          get "services/v1/offerings/foobar-version", {}, auth_header
          last_response.status.should == 200

          resp = Yajl::Parser.parse(last_response.body)
          resp["label"].should == "foobar"
          resp["url"].should   == "http://www.google.com"
          resp["plans"].sort.should == %w[free nonfree]
          resp["provider"].should == "core"
        end

        it "should return the specific service offering which has specific provider" do
          get "services/v1/offerings/foobar-version/test", {}, {"HTTP_X_VCAP_SERVICE_TOKEN" => @svc2.service_auth_token.token}
          last_response.status.should == 200

          resp = Yajl::Parser.parse(last_response.body)
          resp["label"].should == "foobar"
          resp["url"].should   == "http://www.google.com"
          resp["plans"].sort.should == %w[free nonfree]
          resp["provider"].should == "test"
        end
      end

      describe "GET services/v1/offerings/:label_and_version(/:provider)/handles" do
        let!(:svc1) { Models::Service.make(:label => "foobar", :version => "1.0", :provider => "core") }
        let!(:svc2) { Models::Service.make(:label => "foobar", :version => "1.0", :provider => "test") }

        before do
          plan1 = Models::ServicePlan.make(:service => svc1)
          plan2 = Models::ServicePlan.make(:service => svc2)

          cfg1 = Models::ManagedServiceInstance.make(
            :name => "bar1",
            :service_plan => plan1
          )
          cfg1.gateway_name = "foo1"
          cfg1.gateway_data = { :config => "foo1" }
          cfg1.save

          cfg2 = Models::ManagedServiceInstance.make(
            :name => "bar2",
            :service_plan => plan2
          )
          cfg2.gateway_name = "foo2"
          cfg2.gateway_data = { :config => "foo2" }
          cfg2.save

          mock_client.stub(:bind).and_return(
            VCAP::Services::Api::GatewayHandleResponse.new(
              :service_id => "bind1",
              :configuration => { :config => "bind1" },
              :credentials => {}
            )
          )
          Models::ServiceBinding.make(:service_instance  => cfg1)

          mock_client.stub(:bind).and_return(
            VCAP::Services::Api::GatewayHandleResponse.new(
              :service_id => "bind2",
              :configuration => { :config => "bind2" },
              :credentials => {}
            )
          )
          Models::ServiceBinding.make(:gateway_name  => "bind2", :service_instance  => cfg2,)
        end

        it "should return not found for unknown services" do
          get "services/v1/offerings/xxx-version/handles"
          last_response.status.should == 404
        end

        it "should return not found for unknown services with a provider" do
          get "services/v1/offerings/xxx-version/fooprovider/handles"
          last_response.status.should == 404
        end

        it "rejects requests with mismatching tokens" do
          get "/services/v1/offerings/foobar-version/handles", {}, {
            "HTTP_X_VCAP_SERVICE_TOKEN" => "xxx",
          }
          last_response.status.should == 403
        end

        it "should return provisioned and bound handles" do
          get "/services/v1/offerings/foobar-version/handles", {}, {"HTTP_X_VCAP_SERVICE_TOKEN" => svc1.service_auth_token.token}
          last_response.status.should == 200

          handles = JSON.parse(last_response.body)["handles"]
          handles.size.should == 2
          handles[0]["service_id"].should == "foo1"
          handles[0]["configuration"].should == { "config" => "foo1" }
          handles[1]["service_id"].should == "bind1"
          handles[1]["configuration"].should == { "config" => "bind1" }

          get "/services/v1/offerings/foobar-version/test/handles", {}, {"HTTP_X_VCAP_SERVICE_TOKEN" => svc2.service_auth_token.token }
          last_response.status.should == 200

          handles = JSON.parse(last_response.body)["handles"]
          handles.size.should == 2
          handles[0]["service_id"].should == "foo2"
          handles[0]["configuration"].should == { "config" => "foo2" }
          handles[1]["service_id"].should == "bind2"
          handles[1]["configuration"].should == { "config" => "bind2" }
        end
      end

      describe "POST services/v1/offerings/:label_and_version(/:provider)/handles/:id" do
        let!(:svc) { svc = Models::Service.make(:label => "foobar", :provider => "core") }

        before { @auth_header = {"HTTP_X_VCAP_SERVICE_TOKEN" => svc.service_auth_token.token} }

        describe "with default provider" do
          before :each do

            plan = Models::ServicePlan.make(:service => svc)
            cfg = Models::ManagedServiceInstance.make(:name => "bar1", :service_plan => plan)
            cfg.gateway_name = "foo1"
            cfg.save

            mock_client.stub(:bind).and_return(
              VCAP::Services::Api::GatewayHandleResponse.new(
                :service_id => "bind1",
                :configuration => {},
                :credentials => {}
              )
            )
            Models::ServiceBinding.make(:service_instance  => cfg)
          end

          it "should return not found for unknown handles" do
            post "services/v1/offerings/foobar-version/handles/xxx",
              VCAP::Services::Api::HandleUpdateRequest.new(
                :service_id => "xxx",
                :configuration => [],
                :credentials   => []
            ).encode, @auth_header
            last_response.status.should == 404
          end

          it "should update provisioned handles" do
            post "services/v1/offerings/foobar-version/handles/foo1",
              VCAP::Services::Api::HandleUpdateRequest.new(
                :service_id => "foo1",
                :configuration => [],
                :credentials   => []
            ).encode, @auth_header
            last_response.status.should == 200
          end

          it "should update bound handles" do
            post "/services/v1/offerings/foobar-version/handles/bind1",
              VCAP::Services::Api::HandleUpdateRequest.new(
                :service_id => "bind1",
                :configuration => [],
                :credentials   => []
            ).encode, @auth_header
            last_response.status.should == 200
          end
        end

        describe "with specific provider" do
          let!(:svc) { svc = Models::Service.make(:label => "foobar", :provider => "test") }

          before :each do
            plan = Models::ServicePlan.make(
              :service => svc
            )

            cfg = Models::ManagedServiceInstance.make(
              :name         => "bar2",
              :service_plan => plan,
            )
            cfg.gateway_name = "foo2"
            cfg.save

            mock_client.stub(:bind).and_return(
              VCAP::Services::Api::GatewayHandleResponse.new(
                :service_id => "bind2",
                :configuration => {},
                :credentials => {}
              )
            )
            Models::ServiceBinding.make(
              :service_instance  => cfg
            )
          end

          it "should update provisioned handles" do
            post "/services/v1/offerings/foobar-version/test/handles/foo2",
              VCAP::Services::Api::HandleUpdateRequest.new(
                :service_id => "foo2",
                :configuration => [],
                :credentials   => []
            ).encode, @auth_header
            last_response.status.should == 200
          end

          it "should update bound handles" do
            post "/services/v1/offerings/foobar-version/test/handles/bind2",
              VCAP::Services::Api::HandleUpdateRequest.new(
                :service_id => "bind2",
                :configuration => [],
                :credentials   => []
            ).encode, @auth_header
            last_response.status.should == 200
          end
        end
      end

      describe "DELETE /services/v1/offerings/:label_and_version/(:provider)" do
        let!(:service_plan_core) { Models::ServicePlan.make(:service => Models::Service.make(:label => "foobar", :provider => "core")) }
        let!(:service_plan_test) { Models::ServicePlan.make(:service => Models::Service.make(:label => "foobar", :provider => "test")) }
        let(:auth_header) { {"HTTP_X_VCAP_SERVICE_TOKEN" => service_plan_core.service.service_auth_token.token} }

        it "should return not found for unknown label services" do
          delete "/services/v1/offerings/xxx", {}, auth_header
          # FIXME: should really be 404, but upstream gateways don't seem to care
          last_response.status.should == 403
        end

        it "should return not found for unknown provider services" do
          delete "/services/v1/offerings/foobar-version/xxx", {}, auth_header
          # FIXME: should really be 404, but upstream gateways don't seem to care
          last_response.status.should == 403
        end

        it "should return not authorized on token mismatch" do
          delete "/services/v1/offerings/foobar-version/xxx", {}, {
            "HTTP_X_VCAP_SERVICE_TOKEN" => "barfoo",
          }
          last_response.status.should == 403
        end

        it "should delete existing offerings which has null provider" do
          delete "/services/v1/offerings/foobar-version", {}, auth_header
          last_response.status.should == 200

          svc = Models::Service[:label => "foobar", :provider => "core"]
          svc.should be_nil
        end

        it "should delete existing offerings which has specific provider" do
          delete "/services/v1/offerings/foobar-version/test", {}, {"HTTP_X_VCAP_SERVICE_TOKEN" => service_plan_test.service.service_auth_token.token}
          last_response.status.should == 200

          svc = Models::Service[:label => "foobar", :provider => "test"]
          svc.should be_nil
        end
      end

    end
  end
end
