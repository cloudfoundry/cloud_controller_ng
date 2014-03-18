module VCAP::CloudController::RestController
  class CommonParams
    def initialize(logger)
      @logger = logger
    end

    def parse(params)
      @logger.debug "parse_params: #{params}"
      # Sinatra squshes duplicate query parms into a single entry rather
      # than an array (which we might have for q)
      res = {}
      [
        ["inline-relations-depth", Integer],
        ["page", Integer],
        ["results-per-page", Integer],
        ["q", String],
        ["order-direction", String],

      ].each do |key, klass|
        val = params[key]
        res[key.underscore.to_sym] = Object.send(klass.name, val) if val
      end
      res
    end
  end
end
