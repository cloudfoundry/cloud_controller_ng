require 'presenters/system_env_presenter'
require_relative '../../vcap/vars_builder'

module VCAP::CloudController
  module Diego
    class Environment
      EXCLUDE = [:users].freeze

      def initialize(process, initial_env={})
        @process     = process
        @initial_env = initial_env || {}
      end

      def as_json(_={})
        diego_env =
          @initial_env.
          merge(VCAP_APPLICATION: vcap_application, MEMORY_LIMIT: "#{process.memory}m").
          merge(SystemEnvPresenter.new(process.all_service_bindings).system_env).
          merge(process.environment_json || {})

        diego_env = diego_env.merge(DATABASE_URL: process.database_uri) if process.database_uri

        NormalEnvHashToDiegoEnvArrayPhilosopher.muse(diego_env)
      end

      private

      attr_reader :process

      def vcap_application
        VCAP::VarsBuilder.new(process).to_hash.reject do |k, _v|
          EXCLUDE.include? k
        end
      end
    end
  end
end
