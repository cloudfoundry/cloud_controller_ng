require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppGpuFeaturePresenter < BasePresenter
    def to_hash
      {
        name: VCAP::CloudController::AppFeatures::GPU_FEATURE,
        description: 'Require GPU support for the app',
        enabled: app.gpu_enabled
      }
    end

    private

    def app
      @resource
    end
  end
end
