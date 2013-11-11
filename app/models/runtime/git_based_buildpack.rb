module VCAP::CloudController
  class GitBasedBuildpack < Struct.new(:url)
    def to_s
      url
    end

    def to_json
      %Q("#{url}")
    end

    def valid?
      @errors = []
      unless url =~ URI::regexp(%w(http https git))
        @errors << "#{url} is not valid public git url or a known buildpack name"
      end
      return @errors.empty?
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
