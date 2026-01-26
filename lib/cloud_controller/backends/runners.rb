require 'cloud_controller/diego/runner'

module VCAP::CloudController
  class Runners
    def initialize(config)
      @config = config
    end

    def runner_for_process(process)
      Diego::Runner.new(process, @config)
    end
  end
end
