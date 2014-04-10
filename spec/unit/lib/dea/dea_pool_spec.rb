require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::DeaPool do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
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
    subject { DeaPool.new(message_bus) }

    describe "#register_subscriptions" do
      let(:dea_advertise_msg) do
        {
          "id" => "dea-id",
          "stacks" => ["stack"],
          "available_memory" => 1024,
          "available_disk" => 1024,
          "app_id_to_count" => {}
        }
      end

      let(:dea_shutdown_msg) do
        {
          "id" => "dea-id",
          "ip" => "123.123.123.123",
          "version" => "1.2.3",
          "app_id_to_count" => {}
        }
      end

      it "finds advertised dea" do
        subject.register_subscriptions
        message_bus.publish("dea.advertise", dea_advertise_msg)
        expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id")
      end

      it "clears advertisements of DEAs being shut down" do
        subject.register_subscriptions
        message_bus.publish("dea.advertise", dea_advertise_msg)
        message_bus.publish("dea.shutdown", dea_shutdown_msg)

        expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to be_nil
      end
    end

    describe "#find_dea" do
      let(:dea_advertise_msg) do
        {
          "id" => "dea-id",
          "stacks" => ["stack"],
          "available_memory" => 1024,
          "available_disk" => available_disk,
          "app_id_to_count" => {
            "other-app-id" => 1
          }
        }
      end

      def dea_advertisement(options)
        dea_advertisement = {
          "id" => options[:dea],
          "stacks" => ["stack"],
          "available_memory" => options[:memory],
          "available_disk" => available_disk,
          "app_id_to_count" => {
            "app-id" => options[:instance_count]
          }
        }
        if options[:zone]
          dea_advertisement["placement_properties"] = {"zone" => options[:zone]}
        end

        if options[:app_id] && options[:app_id_count]
          dea_advertisement["app_id_to_count"]["#{options[:app_id]}"] = options[:app_id_count]
        end
        dea_advertisement
      end

      let(:dea_in_default_zone_with_1_instance_and_128m_memory) do
        dea_advertisement :dea => "dea-id1", :memory => 128, :instance_count => 1
      end

      let(:dea_in_default_zone_with_2_instances_and_128m_memory) do
        dea_advertisement :dea => "dea-id2", :memory => 128, :instance_count => 2
      end

      let(:dea_in_default_zone_with_1_instance_and_512m_memory) do
        dea_advertisement :dea => "dea-id3", :memory => 512, :instance_count => 1
      end

      let(:dea_in_default_zone_with_2_instances_and_512m_memory) do
        dea_advertisement :dea => "dea-id4", :memory => 512, :instance_count => 2
      end

      let(:dea_in_user_defined_zone_with_3_instances_and_1024m_memory) do
        dea_advertisement :dea => "dea-id5", :memory => 1024, :instance_count => 3, :zone => "zone1"
      end

      let(:dea_in_user_defined_zone_with_2_instances_and_1024m_memory) do
        dea_advertisement :dea => "dea-id6", :memory => 1024, :instance_count => 2, :zone => "zone1"
      end

      let(:dea_in_user_defined_zone_with_1_instance_and_512m_memory) do
        dea_advertisement :dea => "dea-id7", :memory => 512, :instance_count => 1, :zone => "zone1"
      end

      let(:dea_in_user_defined_zone_with_1_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id8", :memory => 256, :instance_count => 1, :zone => "zone1"
      end

      let(:dea9_in_user_defined_zone_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id9", :memory => 256, :instance_count => 0, :zone => "zone1"
      end

      let(:dea10_in_user_defined_zone_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id10", :memory => 256, :instance_count => 0, :zone => "zone1"
      end

      let(:dea11_in_user_defined_zone2_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id11", :memory => 256, :instance_count => 0, :zone => "zone2"
      end

      let(:dea12_in_user_defined_zone2_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id12", :memory => 256, :instance_count => 0, :zone => "zone2"
      end

      let(:dea13_in_user_defined_zone3_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id13", :memory => 256, :instance_count => 0, :zone => "zone3"
      end

      let(:dea14_in_user_defined_zone3_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id14", :memory => 256, :instance_count => 0, :zone => "zone3"
      end

      let(:dea15_in_user_defined_zone3_with_0_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id15", :memory => 256, :instance_count => 0, :zone => "zone3"
      end

      let(:dea16_in_user_defined_zone2_with_0_instance_and_1_other_instance_and_256m_memory) do
        dea_advertisement :dea => "dea-id16", :memory => 256, :instance_count => 0, :zone => "zone2", :app_id => "other-dea-id1", :app_id_count => 1
      end

      let(:dea17_in_user_defined_zone_with_0_instance_and_512m_memory) do
        dea_advertisement :dea => "dea-id17", :memory => 512, :instance_count => 0, :zone => "zone1"
      end

      let(:dea18_in_user_defined_zone2_with_0_instance_and_512m_memory) do
        dea_advertisement :dea => "dea-id18", :memory => 512, :instance_count => 0, :zone => "zone2"
      end

      let(:dea19_in_user_defined_zone3_with_0_instance_and_512m_memory) do
        dea_advertisement :dea => "dea-id19", :memory => 512, :instance_count => 0, :zone => "zone3"
      end

      let(:dea20_in_user_defined_zone3_with_0_instance_and_1024m_memory) do
        dea_advertisement :dea => "dea-id20", :memory => 1024, :instance_count => 0, :zone => "zone3"
      end

      let(:dea21_in_user_defined_dummy_zone_with_0_instance_and_1024m_memory) do
        dea_advertisement :dea => "dea-id21", :memory => 1024, :instance_count => 0, :zone => "dummy"
      end

      let(:available_disk) { 100 }

      describe "dea availability" do
        it "only finds registered deas" do
          expect {
            subject.process_advertise_message(dea_advertise_msg)
          }.to change { subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1) }.from(nil).to("dea-id")
        end
      end

      describe "Invalid zone" do
        it "should not find best dea" do
          subject.process_advertise_message(dea21_in_user_defined_dummy_zone_with_0_instance_and_1024m_memory)
          expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to be nil
        end
      end

      describe "main zone" do
        context "when DEAs are in three zones, for the first instance of an application" do
          it "finds the DEA from the main zone" do
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea10_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea14_in_user_defined_zone3_with_0_instance_and_256m_memory)

            found_dea_ids = []
            10.times do
              found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", index: 0, disk: 1)
            end
            expect(found_dea_ids.uniq).to match_array(%w(dea-id9 dea-id10))
          end
        end

        context "When there was no advertisements in the zone of the No. 1 priority" do
          it "finds a DEA in the zone of the next highest priority" do
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea14_in_user_defined_zone3_with_0_instance_and_256m_memory)

            found_dea_ids = []
            10.times do
              found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", index: 0, disk: 1)
            end
            expect(found_dea_ids.uniq).to match_array(%w(dea-id11 dea-id12))
          end
        end

        context "When the capacity is not met in the dea of main zone" do
          it "finds a DEA, in the zone of the next highest priority, and meeting the condition" do
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea10_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea18_in_user_defined_zone2_with_0_instance_and_512m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea14_in_user_defined_zone3_with_0_instance_and_256m_memory)

            found_dea_ids = []
            10.times do
              found_dea_ids << subject.find_dea(mem: 257, stack: "stack", app_id: "app-id", index: 0,disk: 1)
            end
            expect(found_dea_ids.uniq).to match_array(%w(dea-id18))
          end
        end

        context "When the capacity is not met in the dea of other zone" do
          it "finds a DEA, in the zone of the second candidate, and meeting the condition" do
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea10_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea19_in_user_defined_zone3_with_0_instance_and_512m_memory)

            found_dea_ids = []
            10.times do
              found_dea_ids << subject.find_dea(mem: 257, stack: "stack", app_id: "app-id", index: 1, disk: 1)
            end
            expect(found_dea_ids.uniq).to match_array(%w(dea-id19))
          end
        end

        describe "Invalid zone" do
          it "should not find best dea" do
            subject.process_advertise_message(dea21_in_user_defined_dummy_zone_with_0_instance_and_1024m_memory)
            expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to be nil
          end
        end
      end

      describe "each zone" do
        context "when there are DEAs in three zones and an application with multiple instances" do
          it "finds the DEA from the zone with the most number of dea if the number of the instance is the same" do
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea14_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea15_in_user_defined_zone3_with_0_instance_and_256m_memory)

            dea_id1 = subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: 1)
            subject.mark_app_started(dea_id: dea_id1, app_id: "app-id")
            subject.reserve_app_memory(dea_id1, 1)
            subject.reserve_app_disk(dea_id1, 1)
            dea_id2 = subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: 2)
            subject.mark_app_started(dea_id: dea_id2, app_id: "app-id")
            subject.reserve_app_memory(dea_id2, 1)
            subject.reserve_app_disk(dea_id2, 1)
            dea_id3 = subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: 3)
            subject.mark_app_started(dea_id: dea_id3, app_id: "app-id")
            subject.reserve_app_memory(dea_id3, 1)
            subject.reserve_app_disk(dea_id3, 1)

            expected_dea_ids_in_zone2 = %w(dea-id13 dea-id14 dea-id15)
            expected_dea_ids_in_zone3 = %w(dea-id11 dea-id12)

            expect(expected_dea_ids_in_zone2).to include dea_id1
            expected_dea_ids_in_zone2.delete(dea_id1)
            expect(expected_dea_ids_in_zone3).to include dea_id2
            expect(expected_dea_ids_in_zone2).to include dea_id3
          end

          it "finds the DEA within the each zone" do
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea10_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea14_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea15_in_user_defined_zone3_with_0_instance_and_256m_memory)
            dea_id1 = subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: 0 )
            subject.mark_app_started(dea_id: dea_id1, app_id: "app-id")
            subject.reserve_app_memory(dea_id1, 1)
            subject.reserve_app_disk(dea_id1, 1)
            dea_id2 = subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: 1)
            subject.mark_app_started(dea_id: dea_id2, app_id: "app-id")
            subject.reserve_app_memory(dea_id2, 1)
            subject.reserve_app_disk(dea_id2, 1)
            dea_id3 = subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: 2)
            subject.mark_app_started(dea_id: dea_id3, app_id: "app-id")
            subject.reserve_app_memory(dea_id3, 1)
            subject.reserve_app_disk(dea_id3, 1)

            expect(["dea-id9", "dea-id10"]).to include dea_id1
            expect(["dea-id13", "dea-id14", "dea-id15"]).to include dea_id2
            expect(["dea-id11", "dea-id12"]).to include dea_id3
          end
        end
      end

      describe "each DEA" do
        context "when seven app instances are deployed to seven DEAs in three zones" do
          before do
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea17_in_user_defined_zone_with_0_instance_and_512m_memory)
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea18_in_user_defined_zone2_with_0_instance_and_512m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea19_in_user_defined_zone3_with_0_instance_and_512m_memory)
            subject.process_advertise_message(dea20_in_user_defined_zone3_with_0_instance_and_1024m_memory)
            0.upto(6) { |num|
              self.instance_variable_set("@dea#{num}", subject.find_dea(mem: 1, disk: 1, stack: "stack", app_id: "app-id", index: num))
              dea = self.instance_variable_get("@dea#{num}")
              subject.mark_app_started(dea_id: dea , app_id: "app-id")
            }
          end

          context "when index[0]" do
            it "find the DEA with most available_memory in the main zone(zone1)" do
              expect(@dea0).to eq("dea-id17")
            end
          end

          context "when index[1]" do
            it "finds the DEA with available_memory maximum in the zone(zone3) of the maximum number of dea and in the same application instance of minimum" do
              expect(@dea1).to eq("dea-id20")
            end
          end

          context "when index[2]" do
            it "finds the DEA with available_memory maximum in the zone(zone2) of the maximum number of dea and in the same application instance of minimum" do
              expect(@dea2).to eq("dea-id18")
            end
          end

          context "when index[3]" do
            it "finds the DEA with available_memory maximum in the zone(zone3) of the maximum number of dea" do
              expect(@dea3).to eq("dea-id19")
            end
          end

          context "when index[4]" do
            it "finds the DEA with available_memory maximum in the zone(zone1 or zone2) of the maximum number of dea and in the same application instance of minimum" do
              expected_dea_ids = ["dea-id9", "dea-id11"]
              expected_dea_ids.delete(@dea5)
              expect(expected_dea_ids).to include @dea4
            end
          end

          context "when index[5]" do
            it "finds the DEA with available_memory maximum in the zone(index[4] doesn't selected zone(zone1 and zone2)) of the maximum number of dea and in the same application instance of minimum" do
              expected_dea_ids = ["dea-id9", "dea-id11"]
              expected_dea_ids.delete(@dea4)
              expect(expected_dea_ids).to include @dea5
            end
          end

          context "when index[6]" do
            it "finds the DEA with available_memory maximum in the zone(zone3) of the maximum number of dea and in the same application instance of minimum" do
              expect(@dea6).to eq("dea-id13")
            end
          end
        end
      end

      describe "fewest instance including other application" do
        context "when the DEAs are in 3 zones" do
          it "finds the DEA within other instance number" do
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_256m_memory)
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea16_in_user_defined_zone2_with_0_instance_and_1_other_instance_and_256m_memory)

            expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", index: 1, disk: 1)).to eq("dea-id11")
          end
        end
      end

      describe "specific zone" do
        context "when the user has specified the zone" do
          it "finds DEAs from the specific zone" do
            subject.process_advertise_message(dea9_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea10_in_user_defined_zone_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea11_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea12_in_user_defined_zone2_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea13_in_user_defined_zone3_with_0_instance_and_256m_memory)
            subject.process_advertise_message(dea14_in_user_defined_zone3_with_0_instance_and_256m_memory)

            found_dea_ids = []
            20.times do
              found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", index: 0, zone: "zone3", disk: 1)
              found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", index: 1, zone: "zone3", disk: 1)
            end

            expect(found_dea_ids.uniq).to match_array(%w(dea-id13 dea-id14))
          end
        end
      end

      describe "#only_in_zone_with_fewest_instances" do
        context "when all the DEAs are in the same zone" do
          it "finds the DEA within the default zone" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id1")
          end

          it "finds the DEA with enough memory within the default zone" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            expect(subject.find_dea(mem: 256, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id4")
          end

          it "finds the DEA in user defined zones" do
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id6")
          end
        end

        context "when the instance numbers of all zones are the same" do
          it "finds the only one DEA with the smallest instance number" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id1")
          end

          it "finds the only one DEA with enough memory" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            expect(subject.find_dea(mem: 256, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id4")
          end

          it "finds one of the DEAs with the smallest instance number" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_512m_memory)
            expect(["dea-id1","dea-id7"]).to include (subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1))
          end
        end

        context "when the instance numbers of all zones are different" do
          it "picks the only one DEA in the zone with fewest instances" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id1")
          end

          it "picks one of the DEAs in the zone with fewest instances and upper memory" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_256m_memory)

            expect(["dea-id7"]).to include (subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1))
          end

          it "picks the only DEA with enough resource even it has more instances" do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(subject.find_dea(mem: 384, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id6")
          end

          it "picks DEA in zone with fewest instances even if other zones have more filtered DEAs" do
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(subject.find_dea(mem: 256, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id6")
          end
        end
      end

      describe "dea advertisement expiration (10sec)" do
        it "only finds deas with that have not expired" do
          Timecop.freeze do
            subject.process_advertise_message(dea_advertise_msg)

            Timecop.travel(9)
            expect(subject.find_dea(mem: 1024, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id")

            Timecop.travel(2)
            expect(subject.find_dea(mem: 1024, stack: "stack", app_id: "app-id", disk: 1)).to be_nil
          end
        end
      end

      describe "memory capacity" do
        it "only finds deas that can satisfy memory request" do
          subject.process_advertise_message(dea_advertise_msg)
          expect(subject.find_dea(mem: 1025, stack: "stack", app_id: "app-id", disk: 1)).to be_nil
          expect(subject.find_dea(mem: 1024, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id")
        end
      end

      describe "disk capacity" do
        context "when the disk capacity is not available" do
          let(:available_disk) { 0 }
          it "it doesn't find any deas" do
            subject.process_advertise_message(dea_advertise_msg)
            expect(subject.find_dea(mem: 1024, disk: 10, stack: "stack", app_id: "app-id")).to be_nil
          end
        end

        context "when the disk capacity is available" do
          let(:available_disk) { 50 }
          it "finds the DEA" do
            subject.process_advertise_message(dea_advertise_msg)
            expect(subject.find_dea(mem: 1024, disk: 10, stack: "stack", app_id: "app-id")).to eq("dea-id")
          end
        end

        context "when the disk capacity is not available after placing the instance" do
          let(:available_disk) { 50 }
          it "doesn't find any deas" do
            subject.process_advertise_message(dea_advertise_msg)
            dea_id = subject.find_dea(mem: 1024, disk: 50, stack: "stack", app_id: "app-id")
            subject.mark_app_started(dea_id: dea_id, app_id: "app-id")
            subject.reserve_app_memory(dea_id, 1024)
            subject.reserve_app_disk(dea_id, 50)
            expect(subject.find_dea(mem: 1024, disk: 10, stack: "stack", app_id: "app-id")).to be_nil
          end
        end

      end

      describe "stacks availability" do
        it "only finds deas that can satisfy stack request" do
          subject.process_advertise_message(dea_advertise_msg)
          expect(subject.find_dea(mem: 0, stack: "unknown-stack", app_id: "app-id", disk: 1)).to be_nil
          expect(subject.find_dea(mem: 0, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id")
        end
      end

      describe "existing apps on the instance" do
        before do
          subject.process_advertise_message(dea_advertise_msg)
          subject.process_advertise_message(dea_advertise_msg.merge(
              "id" => "other-dea-id",
              "app_id_to_count" => {
                "app-id" => 1
              }
          ))
        end

        it "picks DEAs that have no existing instances of the app" do
          expect(subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)).to eq("dea-id")
          expect(subject.find_dea(mem: 1, stack: "stack", app_id: "other-app-id", disk: 1)).to eq("other-dea-id")
        end
      end

      context "DEA randomization" do
        before do
          # Even though this fake DEA has more than enough memory, it should not affect results
          # because it already has an instance of the app.
          subject.process_advertise_message(
            dea_advertise_msg.merge("id" => "dea-id-already-has-an-instance",
              "available_memory" => 2048,
              "app_id_to_count" => { "app-id" => 1 })
          )
        end
        context "when all DEAs have the same available memory" do
          before do
            subject.process_advertise_message(dea_advertise_msg.merge("id" => "dea-id1"))
            subject.process_advertise_message(dea_advertise_msg.merge("id" => "dea-id2"))
          end

          it "randomly picks one of the eligible DEAs" do
            found_dea_ids = []
            20.times do
              found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)
            end

            expect(found_dea_ids.uniq).to match_array(%w(dea-id1 dea-id2))
          end
        end

        context "when DEAs have different amounts of available memory" do
          before do
            subject.process_advertise_message(
              dea_advertise_msg.merge("id" => "dea-id1", "available_memory" => 1024)
            )
            subject.process_advertise_message(
              dea_advertise_msg.merge("id" => "dea-id2", "available_memory" => 1023)
            )
          end

          context "and there are only two DEAs" do
            it "always picks the one with the greater memory" do
              found_dea_ids = []
              20.times do
                found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)
              end

              expect(found_dea_ids.uniq).to match_array(%w(dea-id1))
            end
          end

          context "and there are many DEAs" do
            before do
              subject.process_advertise_message(
                dea_advertise_msg.merge("id" => "dea-id3", "available_memory" => 1022)
              )
              subject.process_advertise_message(
                dea_advertise_msg.merge("id" => "dea-id4", "available_memory" => 1021)
              )
              subject.process_advertise_message(
                dea_advertise_msg.merge("id" => "dea-id5", "available_memory" => 1020)
              )
            end

            it "always picks from DEAs of most memory" do
              found_dea_ids = []
              40.times do
                found_dea_ids << subject.find_dea(mem: 1, stack: "stack", app_id: "app-id", disk: 1)
              end

              expect(found_dea_ids.uniq).to match_array(%w(dea-id1))
            end
          end
        end
      end

      describe "multiple instances of an app" do
        before do
          subject.process_advertise_message({
              "id" => "dea-id1",
              "stacks" => ["stack"],
              "available_memory" => 1024,
              "available_disk" => available_disk,
              "app_id_to_count" => {}
            })

          subject.process_advertise_message({
              "id" => "dea-id2",
              "stacks" => ["stack"],
              "available_memory" => 1024,
              "available_disk" => available_disk,
              "app_id_to_count" => {}
            })
        end

        it "will use different DEAs when starting an app with multiple instances" do
          dea_ids = []
          10.times do
            dea_id = subject.find_dea(mem: 0, stack: "stack", app_id: "app-id", disk: 1)
            dea_ids << dea_id
            subject.mark_app_started(dea_id: dea_id, app_id: "app-id")
          end

          expect(dea_ids).to match_array((["dea-id1", "dea-id2"] * 5))
        end
      end

      describe "changing advertisements for the same dea" do
        it "only uses the newest message from a given dea" do
          Timecop.freeze do
            advertisement = dea_advertise_msg.merge("app_id_to_count" => {"app-id" => 1})
            subject.process_advertise_message(advertisement)

            Timecop.travel(5)

            next_advertisement = advertisement.dup
            next_advertisement["available_memory"] = 0
            subject.process_advertise_message(next_advertisement)

            expect(subject.find_dea(mem: 64, stack: "stack", app_id: "foo", disk: 1)).to be_nil
          end
        end
      end
    end

    describe "#reserve_app_memory" do
      let(:available_disk) { 1024 }
      let(:dea_advertise_msg) do
        {
          "id" => "dea-id",
          "stacks" => ["stack"],
          "available_memory" => 1024,
          "available_disk" => available_disk,
          "app_id_to_count" => { "old_app" => 1 }
        }
      end

      let(:new_dea_advertise_msg) do
        {
          "id" => "dea-id",
          "stacks" => ["stack"],
          "available_memory" => 1024,
          "available_disk" => available_disk,
          "app_id_to_count" => { "foo" => 1 }
        }
      end

      it "decrement the available memory based on app's memory" do
        subject.process_advertise_message(dea_advertise_msg)
        expect {
          subject.reserve_app_memory("dea-id", 1)
        }.to change {
          subject.find_dea(mem: 1024, stack: "stack", app_id: "foo", disk:1)
        }.from("dea-id").to(nil)
      end

      it "update the available memory when next time the dea's ad arrives" do
        subject.process_advertise_message(dea_advertise_msg)
        subject.reserve_app_memory("dea-id", 1)
        expect {
          subject.process_advertise_message(new_dea_advertise_msg)
        }.to change {
          subject.find_dea(mem: 1024, stack: "stack", app_id: "foo", disk: 1)
        }.from(nil).to("dea-id")
      end
    end

    describe "#reserve_app_disk" do
      let(:available_disk) { 1024 }
      let(:dea_advertise_msg) do
        {
          "id" => "dea-id",
          "stacks" => ["stack"],
          "available_memory" => 1024,
          "available_disk" => available_disk,
          "app_id_to_count" => { "old_app" => 1 }
        }
      end

      let(:new_dea_advertise_msg) do
        {
          "id" => "dea-id",
          "stacks" => ["stack"],
          "available_memory" => 1024,
          "available_disk" => available_disk,
          "app_id_to_count" => { "foo" => 1 }
        }
      end

      it "decrement the available disk based on app's disk_quota" do
        subject.process_advertise_message(dea_advertise_msg)
        expect {
          subject.reserve_app_disk("dea-id", 1)
        }.to change {
          subject.find_dea(mem: 1024, stack: "stack", app_id: "foo", disk: 1024)
        }.from("dea-id").to(nil)
      end

      it "update the available disk when next time the dea's ad arrives" do
        subject.process_advertise_message(dea_advertise_msg)
        subject.reserve_app_disk("dea-id", 1)
        expect {
          subject.process_advertise_message(new_dea_advertise_msg)
        }.to change {
          subject.find_dea(mem: 1024, stack: "stack", app_id: "foo", disk: 1024)
        }.from(nil).to("dea-id")
      end
    end
  end
end
