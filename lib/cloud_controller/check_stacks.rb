require 'models/runtime/buildpack_lifecycle_data_model'
require 'models/runtime/stack'

module VCAP::CloudController
  class CheckStacks
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def logger
      @logger ||= Steno.logger('cc.install_buildpacks')
    end

    def validate_stacks
    end
  end
end
