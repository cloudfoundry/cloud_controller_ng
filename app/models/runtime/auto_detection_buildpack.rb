module VCAP::CloudController
  class AutoDetectionBuildpack
    def valid?
      true
    end

    def errors
      []
    end

    def staging_message
      {}
    end

    def key
      nil
    end

    def eql?(other)
      other.nil? || other.is_a?(AutoDetectionBuildpack)
    end

    def to_s
      'Auto Detection Buildpack'
    end

    def to_json
      %(null)
    end

    def nil_object?
      true
    end

    def custom?
      false
    end
  end
end
