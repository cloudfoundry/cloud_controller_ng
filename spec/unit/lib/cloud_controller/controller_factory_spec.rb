require 'spec_helper'

module CloudController
  include VCAP::CloudController

  describe ControllerFactory do
    describe '#create_controller' do
      before do
        config = Config.config
        logger = double(:logger).as_null_object
        env = {}
        params = {}
        body = ''
        sinatra = nil

        @controller_factory = ControllerFactory.new(config, logger, env, params, body, sinatra)
        @dependency_locator = DependencyLocator.instance
      end

      it 'instantiates a CrashesController' do
        controller = @controller_factory.create_controller(CrashesController)
        expect(controller).to be_instance_of(CrashesController)
      end

      it 'instantiates a SpaceSummariesController' do
        controller = @controller_factory.create_controller(SpaceSummariesController)
        expect(controller).to be_instance_of(SpaceSummariesController)
      end

      it 'instantiates a CustomBuildpacksController' do
        controller = @controller_factory.create_controller(BuildpacksController)
        expect(controller).to be_instance_of(BuildpacksController)
      end

      it 'instantiates an AppsController' do
        controller = @controller_factory.create_controller(AppsController)
        expect(controller).to be_instance_of(AppsController)
      end

      it 'instantiates a SpacesController' do
        controller = @controller_factory.create_controller(SpacesController)
        expect(controller).to be_instance_of(SpacesController)
      end
    end
  end
end
