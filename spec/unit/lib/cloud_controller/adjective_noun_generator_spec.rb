require 'spec_helper'
require 'set'
require 'cloud_controller/adjective_noun_generator'

module VCAP::CloudController
  RSpec.describe AdjectiveNounGenerator do
    let(:generator) { AdjectiveNounGenerator.new }

    it 'generates a random adjective-noun pair each time it is called' do
      pairs = Set.new((1..10).to_a.map { generator.generate })
      expect(pairs.size).to be > 1
    end

    it 'generates a different set of adjective-noun pairs each time' do
      pairs1 = Set.new((1..10).to_a.map { generator.generate })
      pairs2 = Set.new((1..10).to_a.map { generator.generate })
      expect(pairs1.difference(pairs2)).not_to be_empty
      expect(pairs2.difference(pairs1)).not_to be_empty
    end

    it 'returns an adjective-noun' do
      pair = generator.generate
      expect(pair).to match(/^\w+-\w+$/)
    end
  end
end
