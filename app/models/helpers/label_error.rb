module VCAP::CloudController
  class LabelError < Struct.new(:is_valid?, :message)
    def self.error(message)
      LabelError.new(false, message)
    end

    def self.none
      @none ||= LabelError.new(true)
    end

    def to_s
      "#<LabelError is_valid:#{is_valid?} message:#{message}"
    end
  end
end
