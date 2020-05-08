require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class FeatureFlagPresenter < BasePresenter
    def to_hash
      {
        name: feature_flag.name,
        enabled: feature_flag.enabled,
        updated_at: feature_flag.updated_at,
        custom_error_message: feature_flag.error_message,
        links: feature_flag_links
      }
    end

    private

    def feature_flag
      @resource
    end

    def feature_flag_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/feature_flags/#{feature_flag.name}")
        },
      }
    end
  end
end
