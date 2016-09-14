module VCAP::CloudController
  class CustomBuildpack < Struct.new(:url)
    def to_s
      url
    end

    def to_json
      MultiJson.dump(url)
    end

    def valid?
      @errors = []
      unless url.is_uri?
        @errors << "#{url} is not valid public url or a known buildpack name"
      end
      @errors.empty?
    end

    def errors
      @errors || []
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
