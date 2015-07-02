module VCAP::CloudController
  class BuildpackRequestValidator
    include ActiveModel::Model

    attr_accessor :buildpack, :buildpack_record, :buildpack_url

    validate :buildpack_is_a_uri_or_nil, unless: :buildpack_exists_in_db?

    def buildpack_is_a_uri_or_nil
      return if buildpack.nil?
      if /\A#{URI.regexp}\Z/.match(buildpack)
        @buildpack_url = buildpack
      else
        errors.add(:buildpack, 'must be an existing admin buildpack or a valid git URI')
      end
    end

    def buildpack_exists_in_db?
      @buildpack_record ||= Buildpack.find(name: buildpack)
      !@buildpack_record.nil?
    end

    def to_s
      if @buildpack_url
        @buildpack_url
      else
        @buildpack_record.nil? ? nil : @buildpack_record.name
      end
    end
  end
end
