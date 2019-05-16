module VCAP::CloudController::Presenters::Mixins
  module ServicesPresentationHelpers
    private

    def parse_maintenance_info(maintenance_info)
      return maintenance_info if maintenance_info.is_a?(Hash)

      JSON.parse(maintenance_info)
    rescue JSON::ParserError
      {}
    end
  end
end
