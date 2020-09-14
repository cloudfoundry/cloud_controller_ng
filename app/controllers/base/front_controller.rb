require 'cloud_controller/security/security_context_configurer'
require 'vcap/rest_api'
require 'sinatra/vcap'

module VCAP::CloudController
  include VCAP::RestAPI

  class FrontController < Sinatra::Base
    register Sinatra::VCAP

    attr_reader :config

    vcap_configure(logger_name: 'cc.api', reload_path: File.dirname(__FILE__))

    def initialize(config)
      @config = config
      super()
    end
  end
end
