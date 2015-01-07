require 'spec_helper'
require 'thread'

describe 'Cloud controller', type: :integration do
  before(:all) do
    start_nats
    start_cc
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  context 'upon shutdown' do
    it 'unregisters its route' do
      received = nil

      ready = Queue.new

      thd = Thread.new do
        NATS.start do
          received_count = 0

          sid = NATS.subscribe('router.unregister') do |msg|
            if received_count == 0
              ready << true
            elsif received_count == 1
              received = msg
              NATS.stop
            end

            received_count += 1
          end

          NATS.publish('router.unregister', 'hello') do
            NATS.timeout(sid, 15) do
              fail 'never got anything over NATS'
            end
          end
        end
      end

      ready.pop

      stop_cc

      thd.join

      expected = {
        'host' => '127.0.0.1',
        'port' => 8181,
        'tags' => { 'component' => 'CloudController' },
        'uris' => ['api2.vcap.me'],
        'private_instance_id' => nil,
      }

      expect(received).to match_json(include(expected))
    end
  end
end
