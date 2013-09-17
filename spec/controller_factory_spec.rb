require "spec_helper"

module CloudController
  include VCAP::CloudController

  describe ControllerFactory do
    describe "#create_controller" do
      before do
        config = Config.config
        logger = double(:logger).as_null_object
        env = {}
        params = {}
        body = ""
        sinatra = nil

        @controller_factory = ControllerFactory.new(config, logger, env, params, body, sinatra)
        @dependency_locator = DependencyLocator.instance
      end

      it "instantiates a CrashesController" do
        controller = @controller_factory.create_controller(CrashesController)
        expect(controller).to be_instance_of(CrashesController)
        expect(controller.send(:health_manager_client)).to eq(@dependency_locator.health_manager_client)
      end

      it "instantiates a SpaceSummariesController" do
        controller = @controller_factory.create_controller(SpaceSummariesController)
        expect(controller).to be_instance_of(SpaceSummariesController)
        expect(controller.send(:health_manager_client)).to eq(@dependency_locator.health_manager_client)
      end

      it "instantiates a CustomBuildpacksController" do
        controller = @controller_factory.create_controller(BuildpacksController)
        expect(controller).to be_instance_of(BuildpacksController)
        expect(controller.send(:buildpack_blobstore)).to eq(@dependency_locator.buildpack_blobstore)
        expect(controller.send(:upload_handler)).to eq(@dependency_locator.upload_handler)
      end
    end
  end
end
