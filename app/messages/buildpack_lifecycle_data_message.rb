module VCAP::CloudController
  class BuildpackLifecycleDataMessage < BaseMessage
    register_allowed_keys %i[buildpacks stack]

    validates_with NoAdditionalKeysValidator

    validates :stack,
              string: true,
              allow_nil: true,
              length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }

    validates :buildpacks,
              array: true,
              allow_nil: true

    validate :buildpacks_content

    def buildpacks_content
      return unless buildpacks.is_a?(Array)

      non_string = length_error = false

      buildpacks.each do |buildpack|
        unless buildpack.is_a?(String)
          non_string = true
          next
        end
        length_error = true if buildpack.blank? || buildpack.length > 4096
      end

      errors.add(:buildpacks, 'can only contain strings') if non_string
      errors.add(:buildpacks, 'entries must be between 1 and 4096 characters') if length_error
    end
  end
end
