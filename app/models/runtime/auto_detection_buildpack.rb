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

    def eql?(another)
      another.nil? || another.is_a?(AutoDetectionBuildpack)
    end

    def to_s
      "Auto Detection Buildpack"
    end

    def to_json
      %Q{null}
    end

    def nil_object?
      true
    end

    def custom?
      false
    end
  end
end
