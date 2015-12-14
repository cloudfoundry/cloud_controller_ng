require 'active_model'

module VCAP::CloudController
  class BuildpackLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpack_info, :stack

    validate :buildpack_is_a_uri_or_nil, unless: :buildpack_exists_in_db?
    validate :stack_exists_in_db

    def buildpack_is_a_uri_or_nil
      return if buildpack_info.buildpack.nil?
      return if buildpack_info.buildpack_url
      errors.add(:buildpack, 'must be an existing admin buildpack or a valid git URI')
    end

    def buildpack_exists_in_db?
      !buildpack_info.buildpack_record.nil?
    end

    def stack_exists_in_db
      errors.add(:stack, 'must be an existing stack') if stack.nil?
    end
  end
end
