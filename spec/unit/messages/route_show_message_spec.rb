require 'spec_helper'
require 'messages/route_show_message'

module VCAP::CloudController
  RSpec.describe RouteShowMessage do
    describe 'fields' do
      it 'accepts a string guid param' do
        message = RouteShowMessage.from_params({ 'guid' => 'some-guid' })
        expect(message).to be_valid
      end

      it 'does not accept empty params' do
        message = RouteShowMessage.from_params({})
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include("can't be blank")
      end

      it 'does not accept guid params of incorrect type' do
        message = RouteShowMessage.from_params({ 'guid' => 123 })
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include('must be a string')
      end

      it 'does not accept any other params' do
        message = RouteShowMessage.from_params({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'includes' do
      it 'only allows domains, space, space.organization to be included' do
        message = RouteShowMessage.from_params({ 'guid' => 'some-guid', 'include' => 'domain' })
        expect(message).to be_valid
        message = RouteShowMessage.from_params({ 'guid' => 'some-guid', 'include' => 'space' })
        expect(message).to be_valid
        message = RouteShowMessage.from_params({ 'guid' => 'some-guid', 'include' => 'space.organization' })
        expect(message).to be_valid
        message = RouteShowMessage.from_params({ 'guid' => 'some-guid', 'include' => 'kube' })
        expect(message).not_to be_valid
      end
    end
  end
end
