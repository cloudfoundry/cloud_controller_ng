require 'cgi'

module VCAP::CloudController::RestController
  class CommonParams
    def initialize(logger)
      @logger = logger
    end

    def parse(params, query_string=nil)
      @logger.debug "parse_params: #{params} #{query_string}"
      # Sinatra squashes duplicate query parms into a single entry rather
      # than an array (which we might have for q)
      res = {}
      [
        ['inline-relations-depth', Integer],
        ['page',                   Integer],
        ['results-per-page',       Integer],
        ['q',                      String],
        ['order-by',               String],
        ['order-direction',        String],
        ['orphan-relations',       Integer],
        ['exclude-relations',      String],
        ['include-relations',      String]
      ].each do |key, klass|
        val = params[key]
        res[key.underscore.to_sym] = Object.send(klass.name, val) if val
      end

      res[:q] = CGI.parse(query_string)['q'] if res[:q] && query_string && query_string.count('q=') > 1

      # relationship names should be specified as a comma separated list
      res[:exclude_relations] = res[:exclude_relations].split(',') if res[:exclude_relations]

      res[:include_relations] = res[:include_relations].split(',') if res[:include_relations]

      res
    end
  end
end
