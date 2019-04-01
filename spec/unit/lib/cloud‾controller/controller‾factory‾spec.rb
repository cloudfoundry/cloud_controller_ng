require 'spec_helper'

module CloudController
  RSpec.describe ControllerFactory do
    describe '#create_controller' do
      before do
        config = VCAP::CloudController::Config.config
        logger = double(:logger).as_null_object
        env = {}
        params = {}
        body = ''
        sinatra = nil

        @controller_factory = ControllerFactory.new(config, logger, env, params, body, sinatra)
        @dependency_locator = DependencyLocator.instance
      end

      it 'instantiates a CrashesController' do
        controller = @controller_factory.create_controller(VCAP::CloudController::CrashesController)
        expect(controller).to be_instance_of(VCAP::CloudController::CrashesController)
      end

      it 'instantiates a SpaceSummariesController' do
        controller = @controller_factory.create_controller(VCAP::CloudController::SpaceSummariesController)
        expect(controller).to be_instance_of(VCAP::CloudController::SpaceSummariesController)
      end

      it 'instantiates a CustomBuildpacksController' do
        controller = @controller_factory.create_controller(VCAP::CloudController::BuildpacksController)
        expect(controller).to be_instance_of(VCAP::CloudController::BuildpacksController)
      end

      it 'instantiates an AppsController' do
        controller = @controller_factory.create_controller(VCAP::CloudController::AppsController)
        expect(controller).to be_instance_of(VCAP::CloudController::AppsController)
      end

      it 'instantiates a SpacesController' do
        controller = @controller_factory.create_controller(VCAP::CloudController::SpacesController)
        expect(controller).to be_instance_of(VCAP::CloudController::SpacesController)
      end
    end
  end
end
