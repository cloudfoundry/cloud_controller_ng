require 'rails'
require 'action_controller'

module VCAP
  module CloudController
    module RestController
      class ApplicationCC < ::Rails::Application
        config.middleware.delete 'ActionDispatch::Session::CookieStore'
        config.middleware.delete 'ActionDispatch::Cookies'
        config.middleware.delete 'ActionDispatch::Flash'
        config.middleware.delete 'ActionDispatch::RequestId'
        config.middleware.delete 'Rails::Rack::Logger'
      end

      module V3ErrorsHelper
        def invalid_param!(message)
          raise VCAP::Errors::ApiError.new_from_details('BadQueryParameter', message)
        end

        def unprocessable!(message)
          raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
        end

        def unauthorized!
          raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
        end
      end

      class BaseControllerV3 < ::ActionController::Base
        include VCAP::CloudController
        include VCAP::CloudController::RestController::V3ErrorsHelper

        wrap_parameters :body, format: [:json]

        around_filter :manage_request_id
        before_filter :set_current_user
        before_filter :validate_scheme!
        before_filter :check_read_permissions!, only: [:index, :show]
        before_filter :check_write_permissions!, except: [:index, :show]

        def query_params
          request.query_parameters.with_indifferent_access
        end

        def roles
          VCAP::CloudController::SecurityContext.roles
        end

        def current_user
          VCAP::CloudController::SecurityContext.current_user
        end

        def current_user_email
          VCAP::CloudController::SecurityContext.current_user_email
        end

        private

        ###
        ### FILTERS
        ###

        def manage_request_id
          ::VCAP::Request.current_id = request.env['cf.request_id']
          yield
        ensure
          ::VCAP::Request.current_id = nil
        end

        def check_read_permissions!
          read_scope = SecurityContext.scopes.include?('cloud_controller.read')
          raise VCAP::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !read_scope
        end

        def check_write_permissions!
          write_scope = SecurityContext.scopes.include?('cloud_controller.write')
          raise VCAP::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !write_scope
        end

        def set_current_user
          auth_token = request.headers['HTTP_AUTHORIZATION']
          token_decoder = VCAP::UaaTokenDecoder.new(Config.config[:uaa])
          VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder).configure(auth_token)
        end

        def validate_scheme!
          validator = VCAP::CloudController::RequestSchemeValidator.new
          validator.validate!(current_user, roles, Config.config, request)
        end
      end
    end
  end
end
