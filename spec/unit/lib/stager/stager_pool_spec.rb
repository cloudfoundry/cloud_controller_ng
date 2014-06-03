require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StagerPool do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:staging_advertise_msg) do
      {
          "id" => "staging-id",
          "stacks" => ["stack-name"],
          "available_memory" => 1024,
          "available_disk" => 512,
      }
    end

    subject { StagerPool.new(config, message_bus) }

    describe "#register_subscriptions" do
      it "finds advertised stagers" do
        subject.register_subscriptions
        message_bus.publish("staging.advertise", staging_advertise_msg)
        subject.find_stager("stack-name", 0, 0).should == "staging-id"
      end
    end

    describe "#find_stager" do
      describe "stager availability" do
        it "raises if there are no stagers with that stack" do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager("unknown-stack-name", 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
        end

        it "only finds registered stagers" do
          expect { subject.find_stager("stack-name", 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          subject.process_advertise_message(staging_advertise_msg)
          subject.find_stager("stack-name", 0, 0).should == "staging-id"
        end
      end

      describe "staging advertisement expiration" do
        it "purges expired DEAs" do
          Timecop.freeze do
            subject.process_advertise_message(staging_advertise_msg)

            Timecop.travel(10)
            subject.find_stager("stack-name", 1024, 0).should == "staging-id"

            Timecop.travel(1)
            subject.find_stager("stack-name", 1024, 0).should be_nil
          end
        end
      end

      describe "memory capacity" do
        it "only finds stagers that can satisfy memory request" do
          subject.process_advertise_message(staging_advertise_msg)
          subject.find_stager("stack-name", 1025, 0).should be_nil
          subject.find_stager("stack-name", 1024, 0).should == "staging-id"
        end

        it "samples out of the top 5 stagers with enough memory" do
          (0..9).to_a.shuffle.each do |i|
            subject.process_advertise_message(
              "id" => "staging-id-#{i}",
              "stacks" => ["stack-name"],
              "available_memory" => 1024 * i,
            )
          end

          correct_stagers = (5..9).map { |i| "staging-id-#{i}" }

          10.times do
            expect(correct_stagers).to include(subject.find_stager("stack-name", 1024, 0))
          end
        end
      end

      describe "stack availability" do
        it "only finds deas that can satisfy stack request" do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager("unknown-stack-name", 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          subject.find_stager("stack-name", 0, 0).should == "staging-id"
        end
      end

      describe "disk availability" do
        it "only finds deas that have enough disk" do
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager("stack-name", 1024, 512)).not_to be_nil
          expect(subject.find_stager("stack-name", 1024, 513)).to be_nil
        end
      end
    end

    describe "#reserve_app_memory" do
      let(:stager_advertise_msg) do
        {
            "id" => "staging-id",
            "stacks" => ["stack-name"],
            "available_memory" => 1024,
            "available_disk" => 512
        }
      end

      let(:new_stager_advertise_msg) do
        {
            "id" => "staging-id",
            "stacks" => ["stack-name"],
            "available_memory" => 1024,
            "available_disk" => 512
        }
      end

      it "decrement the available memory based on app's memory" do
        subject.process_advertise_message(stager_advertise_msg)
        expect {
          subject.reserve_app_memory("staging-id", 1)
        }.to change {
          subject.find_stager("stack-name", 1024, 512)
        }.from("staging-id").to(nil)
      end

      it "update the available memory when next time the stager's ad arrives" do
        subject.process_advertise_message(stager_advertise_msg)
        subject.reserve_app_memory("staging-id", 1)
        expect {
          subject.process_advertise_message(new_stager_advertise_msg)
        }.to change {
          subject.find_stager("stack-name", 1024, 512)
        }.from(nil).to("staging-id")
      end
    end
  end
end
