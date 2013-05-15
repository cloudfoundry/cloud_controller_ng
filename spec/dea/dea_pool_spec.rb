# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::DeaPool do
    let(:mock_nats) { NatsClientMock.new({}) }
    let(:message_bus) { MessageBus.new(:nats => mock_nats) }
    subject { DeaPool.new(config, message_bus) }

    describe "#register_subscriptions" do
      let(:dea_advertise_msg) do
        {
          :id => "dea-id",
          :stacks => ["stack"],
          :available_memory => 1024
        }
      end

      it "finds advertised dea" do
        with_em_and_thread do
          subject.register_subscriptions
          EM.next_tick do
            mock_nats.publish("dea.advertise", JSON.dump(dea_advertise_msg))
          end
        end
        subject.find_dea(0, "stack").should == "dea-id"
      end
    end

    describe "#find_dea" do
      let(:dea_advertise_msg) do
        {
          :id => "dea-id",
          :stacks => ["stack"],
          :available_memory => 1024
        }
      end
      describe "dea availability" do
        it "only finds registered deas" do
          expect {
            subject.process_advertise_message(dea_advertise_msg)
          }.to change { subject.find_dea(0, "stack") }.from(nil).to("dea-id")
        end
      end

      describe "dea advertisement expiration (10sec)" do
        it "only finds deas with that have not expired" do
          Timecop.freeze do
            subject.process_advertise_message(dea_advertise_msg)

            Timecop.travel(10)
            subject.find_dea(1024, "stack").should == "dea-id"

            Timecop.travel(1)
            subject.find_dea(1024, "stack").should be_nil
          end
        end
      end

      describe "memory capacity" do
        it "only finds deas that can satisfy memory request" do
          subject.process_advertise_message(dea_advertise_msg)
          subject.find_dea(1025, "stack").should be_nil
          subject.find_dea(1024, "stack").should == "dea-id"
        end
      end

      describe "stacks availability" do
        it "only finds deas that can satisfy stack request" do
          subject.process_advertise_message(dea_advertise_msg)
          subject.find_dea(0, "unknown-stack").should be_nil
          subject.find_dea(0, "stack").should == "dea-id"
        end
      end
    end
  end
end
