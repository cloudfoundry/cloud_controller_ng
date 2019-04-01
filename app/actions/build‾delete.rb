module VCAP::CloudController
  class BuildDelete
    def initialize(cancel_action)
      @cancel_action = cancel_action
    end

    def delete(builds)
      builds = Array(builds)

      @cancel_action.cancel(builds)

      builds.each(&:destroy)
    end
  end
end
