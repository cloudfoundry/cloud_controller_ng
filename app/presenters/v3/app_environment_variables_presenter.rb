module VCAP::CloudController
  module Presenters
    module V3
      class AppEnvironmentVariablesPresenter
        attr_reader :app

        def initialize(app)
          @app = app
        end

        def to_hash
          result = {
            var: {},
            links: build_links
          }

          if !app.environment_variables.nil?
            app.environment_variables.each do |key, value|
              result[:var][key.to_sym] = value
            end
          end

          result
        end

        private

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self: { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/environment_variables") },
            app:  { href: url_builder.build_url(path: "/v3/apps/#{app.guid}") }
          }
        end
      end
    end
  end
end
