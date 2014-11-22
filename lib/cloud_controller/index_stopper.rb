module VCAP::CloudController
  class IndexStopper
    def initialize(runners)
      @runners = runners
    end

    def stop_index(app, index)
      @runners.runner_for_app(app).stop_index(index)
    end
  end
end
