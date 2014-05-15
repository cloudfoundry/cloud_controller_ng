require "spec_helper"

module VCAP::CloudController
  describe StartAppMessage do
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
        res = StartAppMessage.new(app, 1, config, blobstore_url_generator)
        expect(res[:executableUri]).to eq("app_uri")
        res.should be_kind_of(Hash)

        expect(res[:droplet]).to eq(app.guid)
        expect(res[:services]).to be_kind_of(Array)
        expect(res[:services].count).to eq num_service_instances
        expect(res[:services].first).to be_kind_of(Hash)
        expect(res[:limits]).to be_kind_of(Hash)
        expect(res[:env]).to be_kind_of(Array)
        expect(res[:console]).to eq false
        expect(res[:start_command]).to be_nil
        expect(res[:health_check_timeout]).to be_nil

        expect(app.vcap_application).to be
        expect(res[:vcap_application]).to eql(app.vcap_application)

        expect(res[:index]).to eq(1)
      end

      it "should have an app package" do
        res = StartAppMessage.new(app, 1, config, blobstore_url_generator)

        expect(res[:executableUri]).to eq("app_uri")
        expect(res.has_app_package?).to be_true
      end

      context "when no executableUri is present" do
        let(:blobstore_url_generator) do
          double("blobstore_url_generator", :droplet_download_url => nil)
        end

        it "should have no app package" do
          res = StartAppMessage.new(app, 1, config, blobstore_url_generator)

          expect(res[:executableUri]).to be_nil
          expect(res.has_app_package?).to be_false
        end
      end

      context "with an app enabled for console support" do
        it "should enable console in the start message" do
          app.update(:console => true)
          res = StartAppMessage.new(app, 1, config, blobstore_url_generator)
          res[:console].should == true
        end
      end

      context "with an app enabled for debug support" do
        it "should pass debug mode in the start message" do
          app.update(:debug => "run")
          res = StartAppMessage.new(app, 1, config, blobstore_url_generator)
          res[:debug].should == "run"
        end
      end

      context "with an app with custom start command" do
        it "should pass command in the start message" do
          app.update(:command => "custom start command")
          res = StartAppMessage.new(app, 1, config, blobstore_url_generator)
          res[:start_command].should == "custom start command"
        end
      end
      
      context "with an app enabled for custom health check timeout value" do
        it "should enable health check timeout in the start message" do
          app.update(:health_check_timeout => 82)
          res = StartAppMessage.new(app, 1, config, blobstore_url_generator)
          expect(res[:health_check_timeout]).to eq(82)
        end
      end
    end
  end
end
