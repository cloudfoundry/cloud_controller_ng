require 'active_model'

module VCAP::CloudController
  class KpackLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :requested_buildpacks, :buildpack_infos

    validate :buildpacks_are_present

    def buildpacks_are_present
      invalid_buildpacks = requested_buildpacks - buildpack_infos
      invalid_buildpacks.each { |bp| errors.add(:buildpack, %("#{bp}" must be an existing buildpack configured for use with kpack)) }
    end
  end
end
