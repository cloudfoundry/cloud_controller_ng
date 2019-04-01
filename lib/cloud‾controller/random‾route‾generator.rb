require 'cloud_controller/adjective_noun_generator'

module VCAP::CloudController
  class RandomRouteGenerator
    def initialize
      @adjective_noun_generator = AdjectiveNounGenerator.new
    end

    def route
      @adjective_noun_generator.generate
    end
  end
end
