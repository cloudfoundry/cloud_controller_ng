module VCAP::CloudController::Presenters::Mixins
  module ServicesPresentationHelpers
    private

    def parse_maintenance_info(maintenance_info)
      return {} unless maintenance_info
      return maintenance_info if maintenance_info.is_a?(Hash)

      Oj.load(maintenance_info)
    rescue StandardError
      {}
    end
  end
end
