module VCAP::CloudController
  class MetadataError < Struct.new(:is_valid?, :message)
    def self.error(message)
      MetadataError.new(false, message)
    end

    def self.none
      @none ||= MetadataError.new(true)
    end

    def to_s
      "#<MetadataError is_valid:#{is_valid?} message:#{message}"
    end
  end
end
