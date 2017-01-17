require 'spec_helper'

RSpec.describe 'Auth' do
  let(:user) { VCAP::CloudController::User.make }

  before do
    @test_mode = ENV['CC_TEST']
    ENV['CC_TEST'] = nil
  end

  after do
    ENV['CC_TEST'] = @test_mode
  end

  context 'when the user has a valid token' do
    it 'returns as normal' do
      get '/v2/organizations', nil, headers_for(user)
      expect(last_response.status).to eq 200
    end
  end

  context 'when the user has an invalid or expired token' do
    it 'returns a 401' do
      get '/v2/organizations', nil, headers_for(user, expired: true)

      expect(last_response.status).to eq 401
      expect(last_response.body).to match /InvalidAuthToken/
    end
  end
end
