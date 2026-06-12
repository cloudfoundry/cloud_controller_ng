require 'active_model'

module VCAP::CloudController
  class BuildpackLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpack_infos, :stack, :stack_name

    validate :buildpacks_are_uri_or_nil
    validate :stack_exists_in_db
    validate :custom_stack_requires_custom_buildpack

    def custom_stack_requires_custom_buildpack
      return unless UriUtils.is_custom_stack_uri?(stack_name)
      return if buildpack_infos.present? && buildpack_infos.all? { |info| info.buildpack_url.present? }

      errors.add(:buildpack, 'must be a custom buildpack (URL) when using a custom stack')
    end

    def buildpacks_are_uri_or_nil
      buildpack_infos.each do |buildpack_info|
        next if buildpack_info.buildpack_record.present?
        next if buildpack_info.buildpack.nil?
        next if buildpack_info.buildpack_url

        if stack
          errors.add(:buildpack, %("#{buildpack_info.buildpack}" for stack "#{stack.name}" must be an existing admin buildpack or a valid git URI))
        else
          errors.add(:buildpack, %("#{buildpack_info.buildpack}" must be an existing admin buildpack or a valid git URI))
        end
      end
    end

    def stack_exists_in_db
      return if UriUtils.is_custom_stack_uri?(stack_name) && FeatureFlag.enabled?(:diego_custom_stacks)

      errors.add(:stack, 'must be an existing stack') if stack.nil?
    end
  end
end
