require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::Dea::Pool do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    subject { Dea::Pool.new(TestConfig.config, message_bus) }
    let(:available_disk) { 100 }
    let(:dea_advertise_msg) do
      {
        'id' => 'dea-id',
        'stacks' => ['stack'],
        'available_memory' => 1024,
        'available_disk' => available_disk,
        'app_id_to_count' => {
          'other-app-id' => 1
        }
      }
    end

    def find_dea_id(criteria)
      dea = subject.find_dea(criteria)
      return dea.dea_id if dea
      nil
    end

    describe '#register_subscriptions' do
      let(:dea_advertise_msg) do
        {
          'id' => 'dea-id',
          'stacks' => ['stack'],
          'available_memory' => 1024,
          'app_id_to_count' => {}
        }
      end

      let(:dea_shutdown_msg) do
        {
          'id' => 'dea-id',
          'ip' => '123.123.123.123',
          'version' => '1.2.3',
          'app_id_to_count' => {}
        }
      end

      it 'finds advertised dea' do
        subject.register_subscriptions
        message_bus.publish('dea.advertise', dea_advertise_msg)
        expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')).to eq('dea-id')
      end

      it 'clears advertisements of DEAs being shut down' do
        subject.register_subscriptions
        message_bus.publish('dea.advertise', dea_advertise_msg)
        message_bus.publish('dea.shutdown', dea_shutdown_msg)

        expect(subject.find_dea(mem: 1, stack: 'stack', app_id: 'app-id')).to be_nil
      end
    end

    describe '#find_dea' do
      def dea_advertisement(options)
        dea_advertisement = {
          'id' => options[:dea],
          'stacks' => ['stack'],
          'available_memory' => options[:memory],
          'available_disk' => available_disk,
          'app_id_to_count' => {
            'app-id' => options[:instance_count]
          }
        }
        if options[:zone]
          dea_advertisement['placement_properties'] = { 'zone' => options[:zone] }
        end

        dea_advertisement
      end

      let(:dea_in_default_zone_with_1_instance_and_128m_memory) do
        dea_advertisement dea: 'dea-id1', memory: 128, instance_count: 1
      end

      let(:dea_in_default_zone_with_2_instances_and_128m_memory) do
        dea_advertisement dea: 'dea-id2', memory: 128, instance_count: 2
      end

      let(:dea_in_default_zone_with_1_instance_and_512m_memory) do
        dea_advertisement dea: 'dea-id3', memory: 512, instance_count: 1
      end

      let(:dea_in_default_zone_with_2_instances_and_512m_memory) do
        dea_advertisement dea: 'dea-id4', memory: 512, instance_count: 2
      end

      let(:dea_in_user_defined_zone_with_3_instances_and_1024m_memory) do
        dea_advertisement dea: 'dea-id5', memory: 1024, instance_count: 3, zone: 'zone1'
      end

      let(:dea_in_user_defined_zone_with_2_instances_and_1024m_memory) do
        dea_advertisement dea: 'dea-id6', memory: 1024, instance_count: 2, zone: 'zone1'
      end

      let(:dea_in_user_defined_zone_with_1_instance_and_512m_memory) do
        dea_advertisement dea: 'dea-id7', memory: 512, instance_count: 2, zone: 'zone1'
      end

      let(:dea_in_user_defined_zone_with_1_instance_and_256m_memory) do
        dea_advertisement dea: 'dea-id8', memory: 256, instance_count: 1, zone: 'zone1'
      end

      it 'returns a dea advertisement' do
        dea = subject.process_advertise_message(dea_advertise_msg)
        expect(dea).to be_a(Dea::NatsMessages::DeaAdvertisement)
      end

      describe 'dea availability' do
        it 'only finds registered deas' do
          expect {
            subject.process_advertise_message(dea_advertise_msg)
          }.to change { find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id') }.from(nil).to('dea-id')
        end
      end

      describe '#only_in_zone_with_fewest_instances' do
        context 'when all the DEAs are in the same zone' do
          it 'finds the DEA within the default zone' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')).to eq('dea-id1')
          end

          it 'finds the DEA with enough memory within the default zone' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            expect(find_dea_id(mem: 256, stack: 'stack', app_id: 'app-id')).to eq('dea-id4')
          end

          it 'finds the DEA in user defined zones' do
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')).to eq('dea-id6')
          end
        end

        context 'when the instance numbers of all zones are the same' do
          it 'finds the only one DEA with the smallest instance number' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')).to eq('dea-id1')
          end

          it 'finds the only one DEA with enough memory' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            expect(find_dea_id(mem: 256, stack: 'stack', app_id: 'app-id')).to eq('dea-id4')
          end

          it 'finds one of the DEAs with the smallest instance number' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_512m_memory)
            expect(['dea-id1', 'dea-id7']).to include(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id'))
          end
        end

        context 'when the instance numbers of all zones are different' do
          it 'picks the only one DEA in the zone with fewest instances' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')).to eq('dea-id1')
          end

          it 'picks one of the DEAs in the zone with fewest instances' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_1_instance_and_256m_memory)

            expect(['dea-id7', 'dea-id8']).to include(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id'))
          end

          it 'picks the only DEA with enough resource even it has more instances' do
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_3_instances_and_1024m_memory)
            expect(find_dea_id(mem: 768, stack: 'stack', app_id: 'app-id')).to eq('dea-id5')
          end

          it 'picks DEA in zone with fewest instances even if other zones have more filtered DEAs' do
            subject.process_advertise_message(dea_in_default_zone_with_2_instances_and_128m_memory)
            subject.process_advertise_message(dea_in_default_zone_with_1_instance_and_512m_memory)
            subject.process_advertise_message(dea_in_user_defined_zone_with_2_instances_and_1024m_memory)
            expect(find_dea_id(mem: 256, stack: 'stack', app_id: 'app-id')).to eq('dea-id6')
          end
        end
      end

      describe 'dea advertisement expiration' do
        it 'only finds deas with that have not expired' do
          Timecop.freeze do
            subject.process_advertise_message(dea_advertise_msg)

            Timecop.travel(9)
            expect(find_dea_id(mem: 1024, stack: 'stack', app_id: 'app-id')).to eq('dea-id')

            Timecop.travel(2)
            expect(find_dea_id(mem: 1024, stack: 'stack', app_id: 'app-id')).to be_nil
          end
        end

        context 'when the expiration timeout is specified' do
          before { TestConfig.override({ dea_advertisement_timeout_in_seconds: 15 }) }
          it 'only finds deas with that have not expired' do
            Timecop.freeze do
              subject.process_advertise_message(dea_advertise_msg)

              Timecop.travel(13)
              expect(find_dea_id(mem: 1024, stack: 'stack', app_id: 'app-id')).to eq('dea-id')

              Timecop.travel(2)
              expect(find_dea_id(mem: 1024, stack: 'stack', app_id: 'app-id')).to be_nil
            end
          end
        end
      end

      describe 'memory capacity' do
        it 'only finds deas that can satisfy memory request' do
          subject.process_advertise_message(dea_advertise_msg)
          expect(find_dea_id(mem: 1025, stack: 'stack', app_id: 'app-id')).to be_nil
          expect(find_dea_id(mem: 1024, stack: 'stack', app_id: 'app-id')).to eq('dea-id')
        end
      end

      describe 'disk capacity' do
        context 'when the disk capacity is not available' do
          let(:available_disk) { 0 }
          it "it doesn't find any deas" do
            subject.process_advertise_message(dea_advertise_msg)
            expect(find_dea_id(mem: 1024, disk: 10, stack: 'stack', app_id: 'app-id')).to be_nil
          end
        end

        context 'when the disk capacity is available' do
          let(:available_disk) { 50 }
          it 'finds the DEA' do
            subject.process_advertise_message(dea_advertise_msg)
            expect(find_dea_id(mem: 1024, disk: 10, stack: 'stack', app_id: 'app-id')).to eq('dea-id')
          end
        end
      end

      describe 'stacks availability' do
        it 'only finds deas that can satisfy stack request' do
          subject.process_advertise_message(dea_advertise_msg)
          expect(find_dea_id(mem: 0, stack: 'unknown-stack', app_id: 'app-id')).to be_nil
          expect(find_dea_id(mem: 0, stack: 'stack', app_id: 'app-id')).to eq('dea-id')
        end
      end

      describe 'existing apps on the instance' do
        before do
          subject.process_advertise_message(dea_advertise_msg)
          subject.process_advertise_message(
            dea_advertise_msg.merge(
              'id' => 'other-dea-id',
              'app_id_to_count' => {
                'app-id' => 1
              }
          ))
        end

        it 'picks DEAs that have no existing instances of the app' do
          expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')).to eq('dea-id')
          expect(find_dea_id(mem: 1, stack: 'stack', app_id: 'other-app-id')).to eq('other-dea-id')
        end
      end

      context 'DEA randomization' do
        before do
          # Even though this fake DEA has more than enough memory, it should not affect results
          # because it already has an instance of the app.
          subject.process_advertise_message(
            dea_advertise_msg.merge('id' => 'dea-id-already-has-an-instance',
                                    'available_memory' => 2048,
                                    'app_id_to_count' => { 'app-id' => 1 })
          )
        end
        context 'when all DEAs have the same available memory' do
          before do
            subject.process_advertise_message(dea_advertise_msg.merge('id' => 'dea-id1'))
            subject.process_advertise_message(dea_advertise_msg.merge('id' => 'dea-id2'))
          end

          it 'randomly picks one of the eligible DEAs' do
            found_dea_ids = []
            20.times do
              found_dea_ids << find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')
            end

            expect(found_dea_ids.uniq).to match_array(%w(dea-id1 dea-id2))
          end
        end

        context 'when DEAs have different amounts of available memory' do
          before do
            subject.process_advertise_message(
              dea_advertise_msg.merge('id' => 'dea-id1', 'available_memory' => 1024)
            )
            subject.process_advertise_message(
              dea_advertise_msg.merge('id' => 'dea-id2', 'available_memory' => 1023)
            )
          end

          context 'and there are only two DEAs' do
            it 'always picks the one with the greater memory' do
              found_dea_ids = []
              20.times do
                found_dea_ids << find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')
              end

              expect(found_dea_ids.uniq).to match_array(%w(dea-id1))
            end
          end

          context 'and there are many DEAs' do
            before do
              subject.process_advertise_message(
                dea_advertise_msg.merge('id' => 'dea-id3', 'available_memory' => 1022)
              )
              subject.process_advertise_message(
                dea_advertise_msg.merge('id' => 'dea-id4', 'available_memory' => 1021)
              )
              subject.process_advertise_message(
                dea_advertise_msg.merge('id' => 'dea-id5', 'available_memory' => 1020)
              )
            end

            it 'always picks from the half of the list (rounding up) with greater memory' do
              found_dea_ids = []
              40.times do
                found_dea_ids << find_dea_id(mem: 1, stack: 'stack', app_id: 'app-id')
              end

              expect(found_dea_ids.uniq).to match_array(%w(dea-id1 dea-id2 dea-id3))
            end
          end
        end
      end

      describe 'multiple instances of an app' do
        before do
          subject.process_advertise_message({
            'id' => 'dea-id1',
            'stacks' => ['stack'],
            'available_memory' => 1024,
            'app_id_to_count' => {}
          })

          subject.process_advertise_message({
            'id' => 'dea-id2',
            'stacks' => ['stack'],
            'available_memory' => 1024,
            'app_id_to_count' => {}
          })
        end

        it 'will use different DEAs when starting an app with multiple instances' do
          dea_ids = []
          10.times do
            dea_id = find_dea_id(mem: 0, stack: 'stack', app_id: 'app-id')
            dea_ids << dea_id
            subject.mark_app_started(dea_id: dea_id, app_id: 'app-id')
          end

          expect(dea_ids).to match_array((['dea-id1', 'dea-id2'] * 5))
        end
      end

      describe 'changing advertisements for the same dea' do
        it 'only uses the newest message from a given dea' do
          Timecop.freeze do
            advertisement = dea_advertise_msg.merge('app_id_to_count' => { 'app-id' => 1 })
            subject.process_advertise_message(advertisement)

            Timecop.travel(5)

            next_advertisement = advertisement.dup
            next_advertisement['available_memory'] = 0
            subject.process_advertise_message(next_advertisement)

            expect(find_dea_id(mem: 64, stack: 'stack', app_id: 'foo')).to be_nil
          end
        end
      end
    end

    describe '#find_stager' do
      describe 'stager availability' do
        it 'raises if there are no stagers with that stack' do
          subject.process_advertise_message(dea_advertise_msg)
          expect { subject.find_stager('unknown-stack-name', 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
        end

        it 'only finds registered stagers' do
          expect { subject.find_stager('stack', 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          subject.process_advertise_message(dea_advertise_msg)
          expect(subject.find_stager('stack', 0, 0)).to eq('dea-id')
        end
      end

      context 'placement percentage' do
        let(:placement_percentage) { 15 }
        before { TestConfig.override({ placement_top_stager_percentage: placement_percentage }) }

        it 'samples out of the top 15% stagers' do
          (0..99).to_a.shuffle.each do |i|
            subject.process_advertise_message(
              'id' => "staging-id-#{i}",
              'stacks' => ['stack-name'],
              'available_memory' => 1024 * i,
            )
          end

          samples = []
          1000.times do
            samples.push(subject.find_stager('stack-name', 1024, 0))
          end
          expect(samples.uniq.size).to be_within(1).of(placement_percentage)
        end
      end

      describe 'staging advertisement expiration' do
        it 'purges expired DEAs' do
          Timecop.freeze do
            subject.process_advertise_message(dea_advertise_msg)

            Timecop.travel(9)
            expect(subject.find_stager('stack', 1024, 0)).to eq('dea-id')

            Timecop.travel(1)
            expect(subject.find_stager('stack', 1024, 0)).to be_nil
          end
        end

        context 'when an the expiration timeout is specified' do
          before { TestConfig.override({ dea_advertisement_timeout_in_seconds: 15 }) }

          it 'purges expired DEAs' do
            Timecop.freeze do
              subject.process_advertise_message(dea_advertise_msg)

              Timecop.travel(11)
              expect(subject.find_stager('stack', 1024, 0)).to eq('dea-id')

              Timecop.travel(5)
              expect(subject.find_stager('stack', 1024, 0)).to be_nil
            end
          end
        end
      end

      describe 'memory capacity' do
        it 'only finds stagers that can satisfy memory request' do
          subject.process_advertise_message(dea_advertise_msg)
          expect(subject.find_stager('stack', 1025, 0)).to be_nil
          expect(subject.find_stager('stack', 1024, 0)).to eq('dea-id')
        end

        it 'samples out of the top 5 stagers with enough memory' do
          (0..9).to_a.shuffle.each do |i|
            subject.process_advertise_message(
              'id' => "staging-id-#{i}",
              'stacks' => ['stack-name'],
              'available_memory' => 1024 * i,
            )
          end

          correct_stagers = (5..9).map { |i| "staging-id-#{i}" }

          10.times do
            expect(correct_stagers).to include(subject.find_stager('stack-name', 1024, 0))
          end
        end
      end

      describe 'stack availability' do
        it 'only finds deas that can satisfy stack request' do
          subject.process_advertise_message(dea_advertise_msg)
          expect { subject.find_stager('unknown-stack-name', 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          expect(subject.find_stager('stack', 0, 0)).to eq('dea-id')
        end
      end

      describe 'disk availability' do
        let(:available_disk) { 512 }

        it 'only finds deas that have enough disk' do
          subject.process_advertise_message(dea_advertise_msg)
          expect(subject.find_stager('stack', 1024, 512)).not_to be_nil
          expect(subject.find_stager('stack', 1024, 513)).to be_nil
        end
      end
    end

    describe '#reserve_app_memory' do
      let(:dea_advertise_msg) do
        {
            'id' => 'dea-id',
            'stacks' => ['stack'],
            'available_memory' => 1024,
            'app_id_to_count' => { 'old_app' => 1 }
        }
      end

      let(:new_dea_advertise_msg) do
        {
            'id' => 'dea-id',
            'stacks' => ['stack'],
            'available_memory' => 1024,
            'app_id_to_count' => { 'foo' => 1 }
        }
      end

      it "decrement the available memory based on app's memory" do
        subject.process_advertise_message(dea_advertise_msg)
        expect {
          subject.reserve_app_memory('dea-id', 1)
        }.to change {
          find_dea_id(mem: 1024, stack: 'stack', app_id: 'foo')
        }.from('dea-id').to(nil)
      end

      it "update the available memory when next time the dea's ad arrives" do
        subject.process_advertise_message(dea_advertise_msg)
        subject.reserve_app_memory('dea-id', 1)
        expect {
          subject.process_advertise_message(new_dea_advertise_msg)
        }.to change {
          find_dea_id(mem: 1024, stack: 'stack', app_id: 'foo')
        }.from(nil).to('dea-id')
      end
    end
  end
end
