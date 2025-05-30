require 'presenters/system_environment/system_env_presenter'
require 'cloud_controller/diego/normal_env_hash_to_diego_env_array_philosopher'
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
        process_memory_limit = process.memory - sidecar_memory_total
        common_json_and_merge do
          {
            'VCAP_APPLICATION' => vcap_application(memory_limit: process_memory_limit),
            'MEMORY_LIMIT' => "#{process_memory_limit}m"
          }
        end
      end

      def as_json_for_sidecar(sidecar)
        sidecar_memory_limit = sidecar.memory || process.memory
        common_json_and_merge do
          {
            'VCAP_APPLICATION' => vcap_application(memory_limit: sidecar_memory_limit),
            'MEMORY_LIMIT' => "#{sidecar_memory_limit}m"
          }
        end
      end

      private

      attr_reader :process

      def common_json_and_merge(&blk)
        diego_env =
          @initial_env.
          merge(process.environment_json || {}).
          merge(blk.call).
          merge(SystemEnvPresenter.new(process).system_env)

        diego_env = diego_env.merge(DATABASE_URL: process.database_uri) if process.database_uri

        NormalEnvHashToDiegoEnvArrayPhilosopher.muse(diego_env)
      end

      def vcap_application(memory_limit:)
        VCAP::VarsBuilder.new(process, memory_limit:).to_hash.except(*EXCLUDE)
      end

      def sidecar_memory_total
        process.sidecars.sum { |sidecar| sidecar.memory || 0 }
      end
    end
  end
end
