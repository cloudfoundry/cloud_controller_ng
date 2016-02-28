module VCAP::CloudController
  class BuildpackInfo
    attr_accessor :buildpack, :buildpack_record, :buildpack_url

    def initialize(buildpack_name_or_url, buildpack_record)
      @buildpack        = buildpack_name_or_url
      @buildpack_record = buildpack_record
      @buildpack_url    = buildpack_name_or_url if /\A#{URI.regexp}\Z/ =~ buildpack_name_or_url
    end

    def buildpack_exists_in_db?
      !buildpack_record.nil?
    end

    def to_s
      if @buildpack_url
        @buildpack_url
      else
        buildpack_record.nil? ? nil : buildpack_record.name
      end
    end
  end
end
