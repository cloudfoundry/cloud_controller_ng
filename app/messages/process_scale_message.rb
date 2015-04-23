require 'active_model'

module VCAP::CloudController
  class ProcessScaleMessage
    include ActiveModel::Model

    attr_accessor :instances
    validates :instances, numericality: { only_integer: true }
  end
end
