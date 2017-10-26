module VCAP::CloudController
  class IndexStopper
    def initialize(runners)
      @runners = runners
    end

    def stop_index(process, index)
      @runners.runner_for_process(process).stop_index(index)
    end
  end
end
