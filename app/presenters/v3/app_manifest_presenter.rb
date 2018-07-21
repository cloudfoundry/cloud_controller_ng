require 'presenters/v3/app_manifest_parsers/name_env_parser'
require 'presenters/v3/app_manifest_parsers/docker_parser'
require 'presenters/v3/app_manifest_parsers/buildpack_parser'
require 'presenters/v3/app_manifest_parsers/services_properties_parser'
require 'presenters/v3/app_manifest_parsers/route_properties_parser'
require 'presenters/v3/app_manifest_parsers/process_properties_parser'

module VCAP::CloudController
  module Presenters
    module V3
      class AppManifestPresenter
        PROPERTY_PARSERS = [
          AppManifestParsers::NameEnvParser.new,
          AppManifestParsers::DockerParser.new,
          AppManifestParsers::BuildpackParser.new,
          AppManifestParsers::ServicesPropertiesParser.new,
          AppManifestParsers::RoutePropertiesParser.new,
          AppManifestParsers::ProcessPropertiesParser.new,
        ].freeze

        def initialize(app, service_bindings, routes)
          @app = app
          @service_bindings = service_bindings
          @routes = routes
        end

        def to_hash
          {
            applications: [
              PROPERTY_PARSERS.each_with_object({}) do |parser, acc|
                acc.merge!(parser.parse(app, service_bindings, routes))
              end.compact
            ]
          }
        end

        private

        attr_reader :app, :service_bindings, :routes

      end
    end
  end
end
