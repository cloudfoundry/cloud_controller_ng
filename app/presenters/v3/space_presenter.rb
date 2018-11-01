require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class SpacePresenter < BasePresenter
    def to_hash
      hash = {
        guid: space.guid,
        created_at: space.created_at,
        updated_at: space.updated_at,
        name: space.name,
        relationships: {
          organization: {
            data: {
              guid: space.organization_guid
            }
          }
        },
        links: build_links,
        metadata: {
            labels: {}
        }
      }

      space.labels.each do |app_label|
        key = [app_label[:key_prefix], app_label[:key_name]].compact.join(VCAP::CloudController::LabelHelpers::KEY_SEPARATOR)
        hash[:metadata][:labels][key] = app_label[:value]
      end

      hash
    end

    private

    def space
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/spaces/#{space.guid}")
        },
        organization: {
          href: url_builder.build_url(path: "/v3/organizations/#{space.organization_guid}")
        },
      }
    end
  end
end
