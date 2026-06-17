module VCAP::CloudController
  module Lifecycles
    DOCKER = 'docker'.freeze
    BUILDPACK = 'buildpack'.freeze
    CNB = 'cnb'.freeze
    TYPES = [BUILDPACK, CNB, DOCKER].freeze
  end
end
