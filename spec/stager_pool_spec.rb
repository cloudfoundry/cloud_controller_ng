# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::StagerPool do
    let(:mock_nats) { NatsClientMock.new({}) }
    let(:message_bus) { MessageBus.new(:nats => mock_nats) }
    subject { StagerPool.new(config, message_bus) }
    
    describe "#register_subscriptions" do
      let(:staging_advertise_msg) do
        {
          :id => "staging-id",
          :stacks => ["stack-name"],
          :available_memory => 1024,
        }
      end
    
      it "finds advertised stagers" do
        with_em_and_thread do
          subject.register_subscriptions
          EM.next_tick do
            mock_nats.publish("staging.advertise", JSON.dump(staging_advertise_msg))
          end
        end
        subject.find_stager("stack-name", 0).should == "staging-id"
      end
    end

    describe "#find_stager" do
      describe "stager availability" do
        let(:staging_advertise_msg) do
          {
            :id => "staging-id",
            :stacks => ["stack-name"],
            :available_memory => 1024,
          }
        end

        it "raises if there are no stagers with that stack" do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager("unknown-stack-name", 0) }.to raise_error(Errors::StackNotFound)
        end

        it "only finds registered stagers" do
          expect { subject.find_stager("stack-name", 0) }.to raise_error(Errors::StackNotFound)
          subject.process_advertise_message(staging_advertise_msg)
          subject.find_stager("stack-name", 0).should == "staging-id"
        end
      end

      describe "staging advertisement expiration (10sec)" do
        let(:staging_advertise_msg) do
          {
            :id => "staging-id",
            :stacks => ["stack-name"],
            :available_memory => 1024,
          }
        end
    
        it "only finds deas with that have not expired" do
          Timecop.freeze do
            subject.process_advertise_message(staging_advertise_msg)
    
            Timecop.travel(10)
            subject.find_stager("stack-name", 1024).should == "staging-id"
    
            Timecop.travel(1)
            subject.find_stager("stack-name", 1024).should be_nil
          end
        end
      end
    
      describe "memory capacity" do
        let(:staging_advertise_msg) do
          {
            :id => "staging-id",
            :stacks => ["stack-name"],
            :available_memory => 1024,
          }
        end

        it "only finds stagers that can satisfy memory request" do
          subject.process_advertise_message(staging_advertise_msg)
          subject.find_stager("stack-name", 1025).should be_nil
          subject.find_stager("stack-name", 1024).should == "staging-id"
        end
      end

      describe "stack availability" do
        let(:staging_advertise_msg) do
          {
            :id => "staging-id",
            :stacks => ["known-stack-name"],
            :available_memory => 1024,
          }
        end

        it "only finds deas that can satisfy runtime request" do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager("unknown-stack-name", 0) }.to raise_error(Errors::StackNotFound)
          subject.find_stager("known-stack-name", 0).should == "staging-id"
        end
      end
    end
  end
end
