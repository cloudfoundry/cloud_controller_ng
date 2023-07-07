require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UaaTokenCache do
    let(:client_id) { 'client-id' }

    before do
      UaaTokenCache.clear!
      Timecop.freeze
    end

    after do
      Timecop.return
    end

    describe '.set_token' do
      it 'sets a token for a client_id' do
        expect { UaaTokenCache.set_token(client_id, 'bearer STUFF', expires_in: 1000) }.
          to change { UaaTokenCache.get_token(client_id) }.from(nil).to('bearer STUFF')
      end

      it 'expires a token after expiry time' do
        UaaTokenCache.set_token(client_id, 'bearer STUFF', expires_in: 1000)
        Timecop.travel(999.seconds.from_now)
        expect(UaaTokenCache.get_token(client_id)).to eq 'bearer STUFF'
        Timecop.travel(2.seconds.from_now)
        expect(UaaTokenCache.get_token(client_id)).to eq nil
      end

      it 'never expires a token where expires in is nil' do
        UaaTokenCache.set_token(client_id, 'bearer STUFF', expires_in: nil)
        Timecop.travel(10000.seconds.from_now)
        expect(UaaTokenCache.get_token(client_id)).to eq 'bearer STUFF'
      end
    end

    describe '.clear!' do
      it 'clears the cache' do
        UaaTokenCache.set_token(client_id, 'bearer STUFF', expires_in: 1000)
        expect(UaaTokenCache.get_token(client_id)).to eq 'bearer STUFF'
        expect { UaaTokenCache.clear! }.to change { UaaTokenCache.get_token(client_id) }.from('bearer STUFF').to(nil)
      end
    end
  end
end
