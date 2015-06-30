module VCAP::CloudController
  class BuildpackRequestValidator
    include ActiveModel::Model

    attr_accessor :buildpack

    validate :buildpack_is_a_uri_or_nil, unless: :buildpack_exists_in_db?

    def buildpack_is_a_uri_or_nil
      return if buildpack.nil?
      unless buildpack =~ /\A#{URI.regexp}\Z/
        errors.add(:buildpack, 'must be an existing admin buildpack or a valid git URI')
      end
    end

    def buildpack_exists_in_db?
      !Buildpack.find(name: buildpack).nil?
    end
  end
end
