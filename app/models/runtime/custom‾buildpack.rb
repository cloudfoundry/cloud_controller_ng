require 'utils/uri_utils'

module VCAP::CloudController
  class CustomBuildpack < Struct.new(:url)
    def to_s
      url
    end

    def to_json
      MultiJson.dump(url)
    end

    def staging_message
      {
        buildpack: url,
        buildpack_git_url: url
      }
    end

    def custom?
      true
    end
  end
end
