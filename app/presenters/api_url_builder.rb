module VCAP::CloudController::Presenters
  class ApiUrlBuilder
    def build_url(path: nil, query: nil)
      my_uri = URI::HTTP.build(host: VCAP::CloudController::Config.config.get(:external_domain), path: path, query: query)
      my_uri.scheme = VCAP::CloudController::Config.config.get(:external_protocol)
      my_uri.to_s
    end
  end
end
