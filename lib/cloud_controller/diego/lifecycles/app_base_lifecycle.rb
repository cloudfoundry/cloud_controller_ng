require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class AppBaseLifecycle
    def initialize(message, app=nil)
      @message = message
      @app_stack = app&.lifecycle_data&.stack

      validation_data = lifecycle_data_for_validation(app)
      db_result = BuildpackLifecycleFetcher.fetch(validation_data[:buildpacks], validation_data[:stack], type)

      @validator = validator_class.new(
        buildpack_infos: db_result[:buildpack_infos],
        stack: db_result[:stack],
        stack_name: stack,
        lifecycle_type: type,
        credentials: effective_credentials(app),
        credentials_from_message: message.buildpack_data.requested?(:credentials)
      )
    end

    delegate :valid?, :errors, to: :validator

    def update_lifecycle_data_model(app)
      requested = %i[buildpacks stack credentials].select { |field| message.buildpack_data.requested?(field) }
      return if requested.empty?

      app.lifecycle_data.buildpacks = buildpacks if requested.include?(:buildpacks)
      app.lifecycle_data.stack = message.buildpack_data.stack if requested.include?(:stack)
      app.lifecycle_data.credentials = message.buildpack_data.credentials if requested.include?(:credentials)
      app.lifecycle_data.save
    end

    private

    attr_reader :message, :validator

    def validator_class
      BuildpackLifecycleDataValidator
    end

    def lifecycle_data_for_validation(app)
      return { buildpacks:, stack: } unless app && validating_stored_buildpacks?

      stored_data = app.lifecycle_data

      {
        buildpacks: stored_data.buildpacks || [],
        stack: message.buildpack_data.requested?(:stack) ? stack : (stored_data.stack || stack)
      }
    end

    def validating_stored_buildpacks?
      return false if message.buildpack_data.requested?(:buildpacks)
      return true if message.buildpack_data.requested?(:stack) && message.buildpack_data.stack.present?

      # Stored URLs are needed to detect embedded userinfo when credentials are added separately.
      message.buildpack_data.requested?(:credentials) &&
        message.buildpack_data.credentials.present?
    end

    def effective_credentials(app)
      stored = app&.lifecycle_data&.then { |ld| ld.respond_to?(:credentials) ? ld.credentials : nil }
      message.buildpack_data.requested?(:credentials) ? message.buildpack_data.credentials : stored
    end

    def buildpacks
      message.buildpack_data.requested?(:buildpacks) ? (message.buildpack_data.buildpacks || []) : []
    end

    def stack
      if message.buildpack_data.requested?(:stack) && !message.buildpack_data.stack.nil?
        message.buildpack_data.stack
      elsif message.buildpack_data.requested?(:buildpacks) || validating_stored_buildpacks?
        @app_stack || Stack.default.name
      else
        Stack.default.name
      end
    end
  end
end
