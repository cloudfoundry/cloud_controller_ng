require 'presenters/v3/to_one_relationship_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class AppDropletRelationshipPresenter < ToOneRelationshipPresenter
        def initialize(resource_path:, related_instance:, relationship_name:, related_resource_name:, app_model:)
          super(resource_path: resource_path,
                related_instance: related_instance,
                relationship_name: relationship_name,
                related_resource_name: related_resource_name)

          @app_model = app_model
        end

        private

        attr_reader :app_model

        def related_link
          url_builder.build_url(path: "/v3/apps/#{app_model.guid}/droplets/current")
        end
      end
    end
  end
end
