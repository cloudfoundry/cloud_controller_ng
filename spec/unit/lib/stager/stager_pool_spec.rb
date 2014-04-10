require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StagerPool do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:staging_advertise_msg) do
      {
          "id" => "staging-id",
          "stacks" => ["stack-name"],
          "available_memory" => 1024,
          "available_disk" => 1024,
          "placement_properties" => {"zone" => "default"},
          "app_id_to_count" => {},
      }
    end

    before do
      VCAP::CloudController::Config.configure_components(TestConfig.config)
    end
    subject { StagerPool.new(TestConfig.config, message_bus) }

    let(:stack_name_and_0m_memory) { {stack: "stack-name", mem: 0, disk: 1024, app_id: 'app-id'} }
    let(:stack_name_and_512m_memory) { {stack: "stack-name", mem: 512, disk: 1024, index: 0,  app_id: 'app-id'} }
    let(:stack_name_and_1024m_memory) { {stack: "stack-name", mem: 1024, disk: 1024, index: 0,  app_id: 'app-id'} }
    let(:stack_name_and_1025m_memory) { {stack: "stack-name", mem: 1025, disk: 1024, index: 0, app_id: 'app-id'} }
    let(:unknown_stack_and_0m_memory) { {stack: "unknown-stack-name", mem: 0, disk: 1024, app_id: 'app-id'} }
    let(:stack_name_and_256m_memory_512m_disk) { {stack: "stack-name", mem: 256, disk: 512, app_id: 'app-id'} }
    let(:stack_name_and_1024m_memory_1024m_disk) { stack_name_and_1024m_memory }
    let(:stack_name_and_1024m_memory_1025m_disk) { {stack: "stack-name", mem: 1024, disk: 1025, index: 0,  app_id: 'app-id'} }

    describe "#register_subscriptions" do
      it "finds advertised stagers" do
        subject.register_subscriptions
        message_bus.publish("staging.advertise", staging_advertise_msg)
        expect(subject.find_stager(stack_name_and_0m_memory)).to eq("staging-id")
      end
    end

    describe "#find_stager" do
      def staging_advertisement(options)
        {
          "id" => options[:dea],
          "stacks" => ["stack-name"],
          "available_disk" => options[:disk] || 1024,
          "available_memory" => options[:memory] || 1024,
          "placement_properties" => options[:zone] && {"zone" => options[:zone]} || {"zone" => "default"},
          "app_id_to_count" => options[:app_id_to_count] || {},
        }
      end

      let(:dea1_in_user_defined_zone1_with_256m_memory) do
        staging_advertisement :dea => "dea-id1", :memory => 256, :zone => "zone1", :disk => 1024
      end
      let(:dea3_in_user_defined_zone2_with_256m_memory) do
        staging_advertisement :dea => "dea-id3", :memory => 256, :zone => "zone2", :disk => 1024
      end
      let(:dea4_in_user_defined_zone2_with_512m_memory) do
        staging_advertisement :dea => "dea-id4", :memory => 512, :zone => "zone2", :disk => 1024
      end
      let(:dea5_in_user_defined_zone3_with_256m_memory) do
        staging_advertisement :dea => "dea-id5", :memory => 256, :zone => "zone3", :disk => 1024
      end
      let(:dea6_in_user_defined_zone3_with_256m_memory) do
        staging_advertisement :dea => "dea-id6", :memory => 256, :zone => "zone3", :disk => 1024
      end
      let(:dea7_in_user_defined_zone1_with_256m_memory_511m_disk) do
        staging_advertisement :dea => "dea-id7", :memory => 256, :zone => "zone1", :disk => 511
      end
      let(:dea8_in_user_defined_zone2_with_256m_memory_512m_disk) do
        staging_advertisement :dea => "dea-id8", :memory => 256, :zone => "zone2", :disk => 512
      end
      let(:dea9_in_user_defined_dummy_zone_with_1024m_memory_1024m_disk) do
        staging_advertisement :dea => "dea-id9", :memory => 1024, :zone => "dummy", :disk => 1024
      end

      describe "zone" do
        let(:zone_hash) {
          {:zones =>
            [
              {"name" => "zone1", "description" => "zone1", "priority" => 100},
              {"name" => "zone2", "description" => "zone2", "priority" => 80},
              {"name" => "zone3", "description" => "zone3", "priority" => 50},
              {"name" => "default", "description" => "default", "priority" => 10}
            ]
          }
        }

        before do
          VCAP::CloudController::Config.configure_components(TestConfig.config.merge(zone_hash))
        end

        context "when the deas are in multiple zones" do
          it "finds the stager within the main zone" do
            subject.process_advertise_message(dea1_in_user_defined_zone1_with_256m_memory)
            subject.process_advertise_message(dea4_in_user_defined_zone2_with_512m_memory)
            subject.process_advertise_message(dea5_in_user_defined_zone3_with_256m_memory)
            subject.process_advertise_message(dea6_in_user_defined_zone3_with_256m_memory)
            expect(["dea-id1"]).to include (subject.find_stager(stack_name_and_0m_memory))
          end

          it "finds the stager within the next main zone" do
            subject.process_advertise_message(dea3_in_user_defined_zone2_with_256m_memory)
            subject.process_advertise_message(dea4_in_user_defined_zone2_with_512m_memory)
            subject.process_advertise_message(dea5_in_user_defined_zone3_with_256m_memory)
            subject.process_advertise_message(dea6_in_user_defined_zone3_with_256m_memory)

            expect(["dea-id4"]).to include (subject.find_stager(stack_name_and_0m_memory))
          end

          context "when a zone does not have sufficient memory" do
            it "finds another zone for staging" do
              subject.process_advertise_message(dea1_in_user_defined_zone1_with_256m_memory)
              subject.process_advertise_message(dea4_in_user_defined_zone2_with_512m_memory)
              expect(["dea-id4"]).to include (subject.find_stager(stack_name_and_512m_memory))
            end
          end

          context "when a zone does not have sufficient disk" do
            it "finds another zone for staging" do
              subject.process_advertise_message(dea7_in_user_defined_zone1_with_256m_memory_511m_disk)
              subject.process_advertise_message(dea8_in_user_defined_zone2_with_256m_memory_512m_disk)
              expect(["dea-id8"]).to include (subject.find_stager(stack_name_and_256m_memory_512m_disk))
            end
          end
        end

        context "when other app instance running" do
          it "find the DEA of 2nd large memory" do
            [
              {:dea => "dea_id1", :memory => 1024,:zone => "zone1", :disk => 1024, :app_id_to_count => {"hoge" => 1}},
              {:dea => "dea_id2", :memory => 1023,:zone => "zone1", :disk => 1024, :app_id_to_count => {}},
            ].each do |msg|
              subject.process_advertise_message(staging_advertisement(msg))
            end

            expect(["dea_id2"]).to include (subject.find_stager(stack_name_and_512m_memory))
          end
        end
      end

      describe "stager availability" do
        it "raises if there are no stagers with that stack" do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager(unknown_stack_and_0m_memory) }.to raise_error(Errors::ApiError, /The requested app stack unknown-stack-name is not available on this system/)
        end

        it "only finds registered stagers" do
          expect { subject.find_stager(stack_name_and_0m_memory) }.to raise_error(Errors::ApiError, /The requested app stack stack-name is not available on this system/)
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager(stack_name_and_0m_memory)).to eq("staging-id")
        end
      end

      describe "staging advertisement expiration" do
        it "purges expired DEAs" do
          Timecop.freeze do
            subject.process_advertise_message(staging_advertise_msg)

            Timecop.travel(10)
            expect(subject.find_stager(stack_name_and_1024m_memory)).to eq("staging-id")

            Timecop.travel(1)
            expect(subject.find_stager(stack_name_and_1024m_memory)).to be_nil
          end
        end

        describe "Invalid zone" do
          it "should not find best stager" do
            subject.process_advertise_message(dea9_in_user_defined_dummy_zone_with_1024m_memory_1024m_disk)
            expect(subject.find_stager(stack_name_and_512m_memory)).to be_nil
          end
        end
      end

      describe "memory capacity" do
        it "only finds stagers that can satisfy memory request" do
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager(stack_name_and_1025m_memory)).to be_nil
          expect(subject.find_stager(stack_name_and_1024m_memory)).to eq("staging-id")
        end

        it "samples out of the top 5 stagers with enough memory" do
          (0..9).to_a.shuffle.each do |i|
            subject.process_advertise_message(
              "id" => "staging-id-#{i}",
              "stacks" => ["stack-name"],
              "available_memory" => 1024 * i,
              "available_disk" => 1024 * i,
              "app_id_to_count" => {},
            )
          end

          correct_stagers = (5..9).map { |i| "staging-id-#{i}" }

          10.times do
            expect(correct_stagers).to include(subject.find_stager(stack_name_and_1024m_memory))
          end
        end
      end

      describe "stack availability" do
        it "only finds deas that can satisfy stack request" do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager(unknown_stack_and_0m_memory) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          expect(subject.find_stager(stack_name_and_0m_memory)).to eq("staging-id")
        end
      end

      describe "disk availability" do
        it "only finds deas that have enough disk" do
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager(stack_name_and_1024m_memory_1024m_disk)).not_to be_nil
          expect(subject.find_stager(stack_name_and_1024m_memory_1025m_disk)).to be_nil
        end
      end
    end

    describe "#reserve_app_memory" do
      let(:stager_advertise_msg) do
        {
            "id" => "staging-id",
            "stacks" => ["stack-name"],
            "available_memory" => 1024,
            "available_disk" => 1024,
            "placement_properties" => {"zone" => "default"},
            "app_id_to_count" => {},
        }
      end

      let(:new_stager_advertise_msg) do
        {
            "id" => "staging-id",
            "stacks" => ["stack-name"],
            "available_memory" => 1024,
            "available_disk" => 1024,
            "placement_properties" => {"zone" => "default"},
            "app_id_to_count" => {},
        }
      end

      it "decrement the available memory based on app's memory" do
        subject.process_advertise_message(stager_advertise_msg)
        expect {
          subject.reserve_app_memory("staging-id", 1)
        }.to change {
          subject.find_stager(stack_name_and_1024m_memory)
        }.from("staging-id").to(nil)
      end

      it "update the available memory when next time the stager's ad arrives" do
        subject.process_advertise_message(stager_advertise_msg)
        subject.reserve_app_memory("staging-id", 1)
        expect {
          subject.process_advertise_message(new_stager_advertise_msg)
        }.to change {
          subject.find_stager(stack_name_and_1024m_memory)
        }.from(nil).to("staging-id")
      end
    end

    describe "#reserve_app_disk" do
      let(:stager_advertise_msg) do
        {
            "id" => "staging-id",
            "stacks" => ["stack-name"],
            "available_memory" => 1024,
            "available_disk" => 512,
            "placement_properties" => {"zone" => "default"},
            "app_id_to_count" => {},
        }
      end

      it "decrement the available disk based on app's disk_quota" do
        subject.process_advertise_message(stager_advertise_msg)
        expect {
          subject.reserve_app_disk("staging-id", 1)
        }.to change {
          subject.find_stager(stack_name_and_256m_memory_512m_disk)
        }.from("staging-id").to(nil)
      end

      it "update the available disk when next time the stager's ad arrives" do
        subject.process_advertise_message(stager_advertise_msg.dup)
        subject.reserve_app_disk("staging-id", 1)
        expect {
          subject.process_advertise_message(stager_advertise_msg)
        }.to change {
          subject.find_stager(stack_name_and_256m_memory_512m_disk)
        }.from(nil).to("staging-id")
      end
    end
  end
end
