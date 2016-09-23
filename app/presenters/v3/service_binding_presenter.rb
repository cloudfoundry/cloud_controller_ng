require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceBindingPresenter < BasePresenter
        def to_hash
          {
            guid:       service_binding.guid,
            type:       service_binding.type,
            data:       present_service_binding,
            created_at: service_binding.created_at,
            updated_at: service_binding.updated_at,
            links:      build_links
          }
        end

        private

        def service_binding
          @resource
        end

        def present_service_binding
          binding_hash               = ::ServiceBindingPresenter.new(service_binding).to_hash
          binding_hash[:credentials] = redact_hash(binding_hash[:credentials])
          binding_hash
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self: { href: url_builder.build_url(path: "/v3/service_bindings/#{service_binding.guid}") },
            service_instance: { href: url_builder.build_url(path: "/v2/service_instances/#{service_binding.service_instance_guid}") },
            app: { href: url_builder.build_url(path: "/v3/apps/#{service_binding.app_guid}") },
          }
        end
      end
    end
  end
end
