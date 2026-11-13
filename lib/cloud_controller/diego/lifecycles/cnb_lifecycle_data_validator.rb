require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  class CNBLifecycleDataValidator < BuildpackLifecycleDataValidator
    validate :no_cnb_userinfo_in_url

    def no_cnb_userinfo_in_url
      buildpack_infos.each do |buildpack_info|
        next unless buildpack_info.buildpack_url
        next unless UriUtils.url_has_userinfo?(buildpack_info.buildpack_url)

        errors.add(:buildpack, 'CNB buildpack URIs must not contain credentials; use data.credentials instead')
      end
    end
  end
end
