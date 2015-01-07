require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::Dea::StagerPool do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:url_generator) { double(:url_generator) }
    let(:staging_advertise_msg) do
      {
        'id' => 'staging-id',
        'stacks' => ['stack-name'],
        'available_memory' => 1024,
        'available_disk' => 512,
      }
    end

    subject { Dea::StagerPool.new(TestConfig.config, message_bus, url_generator) }

    describe '#register_subscriptions' do
      let!(:stager_pool) { subject }

      it 'finds advertised stagers' do
        message_bus.publish('staging.advertise', staging_advertise_msg)
        expect(stager_pool.find_stager('stack-name', 0, 0)).to eq('staging-id')
      end
    end

    describe '#find_stager' do
      describe 'stager availability' do
        it 'raises if there are no stagers with that stack' do
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager('unknown-stack-name', 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
        end

        it 'only finds registered stagers' do
          expect { subject.find_stager('stack-name', 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager('stack-name', 0, 0)).to eq('staging-id')
        end
      end

      describe 'staging advertisement expiration' do
        it 'purges expired DEAs' do
          Timecop.freeze do
            subject.process_advertise_message(staging_advertise_msg)

            Timecop.travel(9)
            expect(subject.find_stager('stack-name', 1024, 0)).to eq('staging-id')

            Timecop.travel(1)
            expect(subject.find_stager('stack-name', 1024, 0)).to be_nil
          end
        end

        context 'when an the expiration timeout is specified' do
          before { TestConfig.override({ dea_advertisement_timeout_in_seconds: 15 }) }

          it 'purges expired DEAs' do
            Timecop.freeze do
              subject.process_advertise_message(staging_advertise_msg)

              Timecop.travel(11)
              expect(subject.find_stager('stack-name', 1024, 0)).to eq('staging-id')

              Timecop.travel(5)
              expect(subject.find_stager('stack-name', 1024, 0)).to be_nil
            end
          end
        end
      end

      describe 'memory capacity' do
        it 'only finds stagers that can satisfy memory request' do
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager('stack-name', 1025, 0)).to be_nil
          expect(subject.find_stager('stack-name', 1024, 0)).to eq('staging-id')
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
          subject.process_advertise_message(staging_advertise_msg)
          expect { subject.find_stager('unknown-stack-name', 0, 0) }.to raise_error(Errors::ApiError, /The stack could not be found/)
          expect(subject.find_stager('stack-name', 0, 0)).to eq('staging-id')
        end
      end

      describe 'disk availability' do
        it 'only finds deas that have enough disk' do
          subject.process_advertise_message(staging_advertise_msg)
          expect(subject.find_stager('stack-name', 1024, 512)).not_to be_nil
          expect(subject.find_stager('stack-name', 1024, 513)).to be_nil
        end
      end
    end

    describe '#reserve_app_memory' do
      let(:stager_advertise_msg) do
        {
          'id' => 'staging-id',
          'stacks' => ['stack-name'],
          'available_memory' => 1024,
          'available_disk' => 512
        }
      end

      let(:new_stager_advertise_msg) do
        {
          'id' => 'staging-id',
          'stacks' => ['stack-name'],
          'available_memory' => 1024,
          'available_disk' => 512
        }
      end

      it "decrement the available memory based on app's memory" do
        subject.process_advertise_message(stager_advertise_msg)
        expect {
          subject.reserve_app_memory('staging-id', 1)
        }.to change {
          subject.find_stager('stack-name', 1024, 512)
        }.from('staging-id').to(nil)
      end

      it "update the available memory when next time the stager's ad arrives" do
        subject.process_advertise_message(stager_advertise_msg)
        subject.reserve_app_memory('staging-id', 1)
        expect {
          subject.process_advertise_message(new_stager_advertise_msg)
        }.to change {
          subject.find_stager('stack-name', 1024, 512)
        }.from(nil).to('staging-id')
      end
    end

    describe 'pre-warming buildpack caches' do
      let(:stager_advertise_msg) do
        {
          'id' => 'staging-id',
          'stacks' => ['stack-name'],
          'available_memory' => 1024,
          'available_disk' => 512
        }
      end

      let(:buildpack_array) { double(:generated_buildpack_arrray) }
      let(:buildpacks_presenter) { double(:buildpacks_presenter, to_staging_message_array: buildpack_array) }

      before do
        subject.process_advertise_message(stager_advertise_msg)
      end

      context 'when the stager is already in the pool' do
        it 'does not send an buildpack advertisement' do
          expect(message_bus).not_to receive(:publish)
          subject.process_advertise_message(stager_advertise_msg)
        end
      end

      context 'when the stager is seen for the first time' do
        it 'publishes a buildpack advertisement' do
          expect(AdminBuildpacksPresenter).to receive(:new).with(url_generator).and_return buildpacks_presenter
          expect(message_bus).to receive(:publish).with('buildpacks', buildpack_array)

          subject.process_advertise_message(stager_advertise_msg.merge('id' => '123'))
        end
      end
    end
  end
end
