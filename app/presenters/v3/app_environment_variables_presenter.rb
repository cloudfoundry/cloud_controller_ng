require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class AppEnvironmentVariablesPresenter < BasePresenter
        attr_reader :app

        def initialize(app)
          @app = app
        end

        def to_hash
          result = {
            var: {},
            links: build_links
          }

          env_vars&.each do |key, value|
            result[:var][key.to_sym] = value
          end

          result
        end

        private

        def env_vars
          app&.environment_variables
        end

        def build_links
          {
            self: { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/environment_variables") },
            app: { href: url_builder.build_url(path: "/v3/apps/#{app.guid}") }
          }
        end
      end
    end
  end
end
