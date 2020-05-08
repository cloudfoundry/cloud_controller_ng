require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class InfoPresenter < BasePresenter
    def to_hash
      {
        build: info.build,
        cli_version: {
          minimum: info.min_cli_version,
          recommended: info.min_recommended_cli_version
        },
        custom: info.custom,
        description: info.description,
        name: info.name,
        version: info.version,
        links: {
          self: { href: build_self },
          support: { href: info.support_address }
        }
      }
    end

    private

    def info
      @resource
    end

    def build_self
      url_builder.build_url(path: '/v3/info')
    end
  end
end
