require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServiceAccountPresenter < BasePresenter
        def to_hash
          {
            guid: @resource.guid,
            name: @resource.name,
            created_at: @resource.created_at,
            updated_at: @resource.updated_at,
            client_id: @resource.client_id,
            certificate_dns_san: @resource.certificate_dns_san,
            enabled: @resource.enabled,
            status: @resource.status,
            relationships: { space: { data: { guid: @resource.space_guid } } },
            links: { self: { href: url_builder.build_url(path: "/v3/service_accounts/#{@resource.guid}") } }
          }
        end
      end
    end
  end
end
