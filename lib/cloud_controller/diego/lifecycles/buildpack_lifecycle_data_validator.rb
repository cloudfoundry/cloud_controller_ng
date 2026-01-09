require 'active_model'

module VCAP::CloudController
  class BuildpackLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpack_infos, :stack

    validate :buildpacks_are_uri_or_nil
    validate :stack_exists_in_db
    validate :custom_stack_requires_custom_buildpack

    def custom_stack_requires_custom_buildpack
      return unless stack.is_a?(String) && is_custom_stack?(stack)
      return if buildpack_infos.all?(&:custom?)

      errors.add(:buildpack, 'must be a custom buildpack when using a custom stack')
    end

    def buildpacks_are_uri_or_nil
      buildpack_infos.each do |buildpack_info|
        next if buildpack_info.buildpack_record.present?
        next if buildpack_info.buildpack.nil?
        next if buildpack_info.buildpack_url

        if stack
          stack_name = stack.is_a?(String) ? stack : stack.name
          errors.add(:buildpack, %("#{buildpack_info.buildpack}" for stack "#{stack_name}" must be an existing admin buildpack or a valid git URI))
        else
          errors.add(:buildpack, %("#{buildpack_info.buildpack}" must be an existing admin buildpack or a valid git URI))
        end
      end
    end

    def stack_exists_in_db
      # Explicitly check for nil first
      if stack.nil?
        errors.add(:stack, 'must be an existing stack')
        return
      end

      # Handle custom stacks (container registry URLs)
      if stack.is_a?(String) && is_custom_stack?(stack) && FeatureFlag.enabled?(:diego_custom_stacks)
        return
      end

      # Handle existing stack objects or string names
      if stack.is_a?(String)
        # For string stack names, verify they exist in the database
        unless VCAP::CloudController::Stack.where(name: stack).any?
          errors.add(:stack, 'must be an existing stack')
        end
      end
      # If stack is an object (not nil, not string), assume it's valid
    end

    private

    def is_custom_stack?(stack_name)
      # Check for various container registry URL formats
      return true if stack_name.include?('docker://')
      return true if stack_name.match?(%r{^https?://})  # Any https/http URL
      return true if stack_name.include?('.')  # Any string with a dot (likely a registry)
      false
    end
  end
end
