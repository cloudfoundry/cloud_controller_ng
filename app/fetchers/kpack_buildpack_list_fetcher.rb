require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/null_filter_query_generator'
require 'messages/buildpacks_list_message'

module VCAP::CloudController
  class KpackBuildpackListFetcher
    def fetch_all(message=EmptyBuildpackListMessage)
      staging_namespace = VCAP::CloudController::Config.config.kpack_builder_namespace
      default_builder = k8s_api_client.get_builder('cf-default-builder', staging_namespace)

      version_map = default_builder.status.builderMetadata.each.with_object({}) do |metadata, h|
        h[metadata.id] = metadata.version
      end
      stack = default_builder.status.stack.id
      created_at = Time.parse(default_builder.metadata.creationTimestamp)

      latest_condition = default_builder.status.conditions[0]
      if latest_condition
        state = Buildpack::READY_STATE
        updated_at = Time.parse(latest_condition.lastTransitionTime)
      else
        state = Buildpack::CREATED_STATE
        updated_at = created_at
      end

      default_builder.spec.order.map do |entry|
        name = entry.group.first.id
        version = version_map.fetch(name, 'unknown')
        KpackBuildpack.new(
          id: "#{name}@#{version}",
          name: name,
          filename: "#{name}@#{version}",
          stack: stack,
          state: state,
          created_at: created_at,
          updated_at: updated_at,
        )
      end
    end

    private

    def k8s_api_client
      @k8s_api_client ||= CloudController::DependencyLocator.instance.k8s_api_client
    end

    class KpackBuildpack
      attr_reader :filename, :id, :name, :stack, :state, :created_at, :updated_at

      def initialize(filename:, id:, name:, stack:, state:, created_at:, updated_at:)
        @filename = filename
        @id = id
        @name = name
        @stack = stack
        @state = state
        @created_at = created_at
        @updated_at = updated_at
      end

      def guid
        nil
      end

      def position
        0
      end

      def enabled?
        true
      end
      alias_method :enabled, :enabled?

      def locked?
        false
      end
      alias_method :locked, :locked?

      def labels
        []
      end

      def annotations
        []
      end
    end
  end
end
