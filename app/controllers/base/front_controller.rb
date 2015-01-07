require 'cloud_controller/security/security_context_configurer'

module VCAP::CloudController
  include VCAP::RestAPI

  Errors = VCAP::Errors

  class FrontController < Sinatra::Base
    register Sinatra::VCAP

    attr_reader :config

    vcap_configure(logger_name: 'cc.api', reload_path: File.dirname(__FILE__))

    def initialize(config, token_decoder)
      @config = config
      @token_decoder = token_decoder
      super()
    end

    before do
      auth_token = env['HTTP_AUTHORIZATION']
      I18n.locale = env['HTTP_ACCEPT_LANGUAGE']

      process_cors_headers
      VCAP::CloudController::Security::SecurityContextConfigurer.new(@token_decoder).configure(auth_token)
      validate_scheme
    end

    private

    def process_cors_headers
      return unless env['HTTP_ORIGIN']
      return unless allowed_cors_domains.any? { |d| d =~ env['HTTP_ORIGIN'] }

      if request.options?
        return unless %w(get put delete post).include?(env['HTTP_ACCESS_CONTROL_REQUEST_METHOD'].to_s.downcase)

        headers['Access-Control-Allow-Methods'] = 'GET,PUT,POST,DELETE'
        headers['Access-Control-Max-Age'] = '900'
        headers['Access-Control-Allow-Headers'] = Set.new(['origin', 'content-type', 'authorization']).
          merge(env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'].to_s.split(',').map(&:strip).map(&:downcase)).to_a.join(',')
      end

      headers['Vary'] = 'Origin'
      headers['Access-Control-Allow-Origin'] = env['HTTP_ORIGIN']
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers['Access-Control-Expose-Headers'] = "x-cf-warnings,x-app-staging-log,#{::VCAP::Request::HEADER_NAME.downcase},location,range"

      halt 200, '' if request.options?
    end

    def validate_scheme
      user = VCAP::CloudController::SecurityContext.current_user
      admin = VCAP::CloudController::SecurityContext.admin?
      return unless user || admin

      if @config[:https_required] && request.scheme != 'https'
        raise Errors::ApiError.new_from_details('NotAuthorized')
      end

      if @config[:https_required_for_admins] && admin && request.scheme != 'https'
        raise Errors::ApiError.new_from_details('NotAuthorized')
      end
    end

    def allowed_cors_domains
      @_allowed_cors_domains ||= @config[:allowed_cors_domains].map { |d| /^#{Regexp.quote(d).gsub('\*', '.*?')}$/ }
    end
  end
end
