require "spec_helper"

module VCAP::CloudController
  describe Dea::StartAppMessage do
    let(:num_service_instances) { 3 }

    let(:app) do
      app = AppFactory.make.tap do |app|
        num_service_instances.times do
          instance = ManagedServiceInstance.make(:space => app.space)
          binding = ServiceBinding.make(
              :app => app,
              :service_instance => instance
          )
          app.add_service_binding(binding)
        end
      end
    end

    let(:blobstore_url_generator) do
      double("blobstore_url_generator", :droplet_download_url => "app_uri")
    end

    describe ".start_app_message" do
      it "should return a serialized dea message" do
        res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)
        expect(res[:executableUri]).to eq("app_uri")
        expect(res).to be_kind_of(Hash)

        expect(res[:droplet]).to eq(app.guid)
        expect(res[:services]).to be_kind_of(Array)
        expect(res[:services].count).to eq num_service_instances
        expect(res[:services].first).to be_kind_of(Hash)
        expect(res[:limits]).to be_kind_of(Hash)
        expect(res[:env]).to be_kind_of(Array)
        expect(res[:console]).to eq false
        expect(res[:start_command]).to be_nil
        expect(res[:health_check_timeout]).to be_nil
        expect(res[:egress_network_rules]).to be_kind_of(Array)
        expect(res[:egress_network_rules]).to eq([])

        expect(app.vcap_application).to be
        expect(res[:vcap_application]).to eql(app.vcap_application)

        expect(res[:index]).to eq(1)
      end

      it "should have an app package" do
        res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)

        expect(res[:executableUri]).to eq("app_uri")
        expect(res.has_app_package?).to be true
      end

      context "when no executableUri is present" do
        let(:blobstore_url_generator) do
          double("blobstore_url_generator", :droplet_download_url => nil)
        end

        it "should have no app package" do
          res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)

          expect(res[:executableUri]).to be_nil
          expect(res.has_app_package?).to be false
        end
      end

      context "with an app enabled for console support" do
        it "should enable console in the start message" do
          app.update(:console => true)
          res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)
          expect(res[:console]).to eq(true)
        end
      end

      context "with an app enabled for debug support" do
        it "should pass debug mode in the start message" do
          app.update(:debug => "run")
          res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)
          expect(res[:debug]).to eq("run")
        end
      end

      context "with an app with custom start command" do
        it "should pass command in the start message" do
          app.update(:command => "custom start command")
          res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)
          expect(res[:start_command]).to eq("custom start command")
        end
      end

      context "with an app enabled for custom health check timeout value" do
        it "should enable health check timeout in the start message" do
          app.update(:health_check_timeout => 82)
          res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)
          expect(res[:health_check_timeout]).to eq(82)
        end
      end

      context "when security groups are configured" do
        let(:sg_default_rules_1) { [{"protocol" => "udp", "ports" => "8080", "destination" => "198.41.191.47/1"}] }
        let(:sg_default_rules_2) { [{"protocol" => "tcp", "ports" => "9090", "destination" => "198.41.191.48/1", "log" => true}] }
        let(:sg_for_space_rules) { [{"protocol" => "udp", "ports" => "1010", "destination" => "198.41.191.49/1"}] }

        before do
          SecurityGroup.make(rules: sg_default_rules_1, running_default: true)
          SecurityGroup.make(rules: sg_default_rules_2, running_default: true)
          app.space.add_security_group(SecurityGroup.make(rules: sg_for_space_rules))
        end

        it "should provide the egress rules in the start message" do
          res = Dea::StartAppMessage.new(app, 1, TestConfig.config, blobstore_url_generator)
          expect(res[:egress_network_rules]).to match_array(
            [ sg_default_rules_1, sg_default_rules_2, sg_for_space_rules ].flatten
          )
        end
      end
    end
  end
end
