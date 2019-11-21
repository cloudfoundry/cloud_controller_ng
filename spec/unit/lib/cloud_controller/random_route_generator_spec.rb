require 'spec_helper'
require 'set'

module VCAP::CloudController
  RSpec.describe RandomRouteGenerator do
    let(:generator) { RandomRouteGenerator.new }

    it 'generates a random route each time it is called' do
      routes = Set.new((1..10).to_a.map { generator.route })
      expect(routes.size).to be > 1
    end

    it 'generates a different set of routes each time' do
      routes1 = Set.new((1..10).to_a.map { generator.route })
      routes2 = Set.new((1..10).to_a.map { generator.route })
      expect(routes1.difference(routes2)).not_to be_empty
      expect(routes2.difference(routes1)).not_to be_empty
    end

    it 'returns an adjective-noun-twoRandomLetters' do
      route = generator.route
      expect(route).to match(/^\w+-\w+-[a-z]{2}$/)
    end
  end
end
