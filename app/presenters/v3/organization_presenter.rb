require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class OrganizationPresenter < BasePresenter
    def to_hash
      hash = {
          guid: organization.guid,
          created_at: organization.created_at,
          updated_at: organization.updated_at,
          name: organization.name,
          links: build_links,
          metadata: {
              labels: {}
          }
      }

      organization.labels.each do |org_label|
        key = [org_label[:key_prefix], org_label[:key_name]].compact.join(VCAP::CloudController::LabelHelpers::KEY_SEPARATOR)
        hash[:metadata][:labels][key] = org_label[:value]
      end

      hash
    end

    private

    def organization
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}") },
      }
    end
  end
end
