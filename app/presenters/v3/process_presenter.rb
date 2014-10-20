module VCAP::CloudController
  class ProcessPresenter
    def initialize(process)
      @process = process
    end

    def present
      {
        guid: @process.guid,
      }
    end
  end
end
