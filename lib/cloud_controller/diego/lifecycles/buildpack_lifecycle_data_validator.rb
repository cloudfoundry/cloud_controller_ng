require 'active_model'

module VCAP::CloudController
  class BuildpackLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpack_infos, :stack

    validate :buildpacks_are_uri_or_nil
    validate :stack_exists_in_db

    def buildpacks_are_uri_or_nil
      buildpack_infos.each do |buildpack_info|
        next if buildpack_info.buildpack_record.present?
        next if buildpack_info.buildpack.nil?
        next if buildpack_info.buildpack_url
        errors.add(:buildpack, %("#{buildpack_info.buildpack}" must be an existing admin buildpack or a valid git URI))
      end
    end

    def stack_exists_in_db
      errors.add(:stack, 'must be an existing stack') if stack.nil?
    end
  end
end
