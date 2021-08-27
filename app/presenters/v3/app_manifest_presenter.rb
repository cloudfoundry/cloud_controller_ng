require 'presenters/v3/app_manifest_presenters/name_env_presenter'
require 'presenters/v3/app_manifest_presenters/docker_presenter'
require 'presenters/v3/app_manifest_presenters/buildpack_presenter'
require 'presenters/v3/app_manifest_presenters/services_properties_presenter'
require 'presenters/v3/app_manifest_presenters/route_properties_presenter'
require 'presenters/v3/app_manifest_presenters/metadata_presenter'
require 'presenters/v3/app_manifest_presenters/process_properties_presenter'
require 'presenters/v3/app_manifest_presenters/sidecar_properties_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class AppManifestPresenter
        PROPERTY_PRESENTERS = [
          AppManifestPresenters::NameEnvPresenter.new,
          AppManifestPresenters::DockerPresenter.new,
          AppManifestPresenters::BuildpackPresenter.new,
          AppManifestPresenters::ServicesPropertiesPresenter.new,
          AppManifestPresenters::RoutePropertiesPresenter.new,
          AppManifestPresenters::MetadataPresenter.new,
          AppManifestPresenters::ProcessPropertiesPresenter.new,
          AppManifestPresenters::SidecarPropertiesPresenter.new,
        ].freeze

        def initialize(app, service_bindings, route_mappings)
          @app = app
          @service_bindings = service_bindings
          @route_mappings = route_mappings
        end

        def to_hash
          {
            applications: [
              PROPERTY_PRESENTERS.each_with_object({}) do |presenter, acc|
                acc.merge!(presenter.to_hash(app: app, service_bindings: service_bindings, route_mappings: route_mappings))
              end.compact
            ]
          }
        end

        private

        attr_reader :app, :service_bindings, :route_mappings
      end
    end
  end
end
