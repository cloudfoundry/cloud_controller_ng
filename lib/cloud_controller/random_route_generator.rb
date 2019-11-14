require 'cloud_controller/adjective_noun_generator'

module VCAP::CloudController
  class RandomRouteGenerator
    def initialize
      @adjective_noun_generator = AdjectiveNounGenerator.new
    end

    def route
      ascii_letter_a = 97
      first_letter = (rand(26) + ascii_letter_a).chr
      second_letter = (rand(26) + ascii_letter_a).chr
      @adjective_noun_generator.generate + "-#{first_letter}#{second_letter}"
    end
  end
end
