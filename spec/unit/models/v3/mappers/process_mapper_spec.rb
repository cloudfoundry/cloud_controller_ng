require 'spec_helper'
require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  describe ProcessMapper do
    describe '.map_model_to_domain' do
      let(:model) { AppFactory.make }

      it 'maps App to AppProcess' do
        process = ProcessMapper.map_model_to_domain(model)

        expect(process.guid).to eq(model.guid)
        expect(process.name).to eq(model.name)
        expect(process.memory).to eq(model.memory)
        expect(process.instances).to eq(model.instances)
        expect(process.disk_quota).to eq(model.disk_quota)
        expect(process.space_guid).to eq(model.space.guid)
        expect(process.stack_guid).to eq(model.stack.guid)
        expect(process.state).to eq(model.state)
        expect(process.command).to eq(model.command)
        expect(process.buildpack).to be_nil
        expect(process.health_check_timeout).to eq(model.health_check_timeout)
        expect(process.docker_image).to eq(model.docker_image)
        expect(process.environment_json).to eq(model.environment_json)
      end
    end

    describe '.map_domain_to_model' do
      let(:space) { Space.make }
      let(:stack) { Stack.make }

      let(:valid_opts) do
        {
          name:                 'some-name',
          space_guid:           space.guid,
          stack_guid:           stack.guid,
          disk_quota:           32,
          memory:               456,
          instances:            51,
          state:                'STARTED',
          command:              'start-command',
          buildpack:            'buildpack',
          health_check_timeout: 3,
          docker_image:         'docker_image',
          environment_json:     'env_json'
        }
      end
      let(:custom_opts) { {} }
      let(:proc_opts) { valid_opts.merge(custom_opts) }
      let(:process) { AppProcess.new(proc_opts) }

      context 'and the app has been saved' do
        let(:app) { AppFactory.make }
        let(:custom_opts) { { guid: app.guid } }

        it 'maps AppProcess to App' do
          model = ProcessMapper.map_domain_to_model(process)

          expect(model.guid).to eq(app.guid)
          expect(model.name).to eq('some-name')
          expect(model.memory).to eq(456)
          expect(model.instances).to eq(51)
          expect(model.disk_quota).to eq(32)
          expect(model.space_guid).to eq(space.guid)
          expect(model.stack_guid).to eq(stack.guid)
          expect(model.state).to eq('STARTED')
          expect(model.command).to eq('start-command')
          expect(model.buildpack.url).to eq('buildpack')
          expect(model.health_check_timeout).to eq(3)
          expect(model.docker_image).to eq('docker_image:latest')
          expect(model.environment_json).to eq('env_json')
        end
      end

      context 'and the app has not been persisted' do
        let(:custom_opts) { { guid: nil } }

        it 'maps AppProcess to App' do
          model = ProcessMapper.map_domain_to_model(process)

          expect(model.guid).to be_nil
          expect(model.name).to eq('some-name')
          expect(model.memory).to eq(456)
          expect(model.instances).to eq(51)
          expect(model.disk_quota).to eq(32)
          expect(model.space_guid).to eq(space.guid)
          expect(model.stack_guid).to eq(stack.guid)
          expect(model.state).to eq('STARTED')
          expect(model.command).to eq('start-command')
          expect(model.buildpack.url).to eq('buildpack')
          expect(model.health_check_timeout).to eq(3)
          expect(model.docker_image).to eq('docker_image:latest')
          expect(model.environment_json).to eq('env_json')
        end

        context 'and some values are nil' do
          let(:custom_opts) { { guid: nil, instances: nil } }

          it 'does not map map them' do
            model = ProcessMapper.map_domain_to_model(process)

            expect(model.guid).to be_nil
            expect(model.name).to eq('some-name')
            expect(model.memory).to eq(456)
            expect(model.instances).to_not be_nil
            expect(model.disk_quota).to eq(32)
            expect(model.space_guid).to eq(space.guid)
            expect(model.stack_guid).to eq(stack.guid)
            expect(model.state).to eq('STARTED')
            expect(model.command).to eq('start-command')
            expect(model.buildpack.url).to eq('buildpack')
            expect(model.health_check_timeout).to eq(3)
            expect(model.docker_image).to eq('docker_image:latest')
            expect(model.environment_json).to eq('env_json')
          end
        end

        context 'but we search for a persisted app' do
          let(:custom_opts) { { guid: 'bogus' } }

          it 'returns nil' do
            expect(ProcessMapper.map_domain_to_model(process)).to be_nil
          end
        end
      end
    end

    describe 'round trip mapping' do
      let(:space) { Space.make }
      let(:stack) { Stack.make }
      let(:valid_opts) do
        {
          name:                 'some-name',
          space_guid:           space.guid,
          stack_guid:           stack.guid,
          disk_quota:           32,
          memory:               456,
          instances:            51,
          state:                'STARTED',
          command:              'start-command',
          buildpack:            'buildpack',
          health_check_timeout: 3,
          docker_image:         'docker_image',
          environment_json:     'env_json'
        }
      end
      let(:process) { AppProcess.new(valid_opts) }

      it 'works' do
        expect(process.name).to eq('some-name')
        expect(process.memory).to eq(456)
        expect(process.instances).to eq(51)
        expect(process.disk_quota).to eq(32)
        expect(process.space_guid).to eq(space.guid)
        expect(process.stack_guid).to eq(stack.guid)
        expect(process.state).to eq('STARTED')
        expect(process.command).to eq('start-command')
        expect(process.buildpack).to eq('buildpack')
        expect(process.health_check_timeout).to eq(3)
        expect(process.docker_image).to eq('docker_image')
        expect(process.environment_json).to eq('env_json')

        model = ProcessMapper.map_domain_to_model(process)

        expect(model.name).to eq('some-name')
        expect(model.memory).to eq(456)
        expect(model.instances).to eq(51)
        expect(model.disk_quota).to eq(32)
        expect(model.space_guid).to eq(space.guid)
        expect(model.stack_guid).to eq(stack.guid)
        expect(model.state).to eq('STARTED')
        expect(model.command).to eq('start-command')
        expect(model.buildpack.url).to eq('buildpack')
        expect(model.health_check_timeout).to eq(3)
        expect(model.docker_image).to eq('docker_image:latest')
        expect(model.environment_json).to eq('env_json')

        roundtrip_process = ProcessMapper.map_model_to_domain(model)

        expect(roundtrip_process.name).to eq('some-name')
        expect(roundtrip_process.memory).to eq(456)
        expect(roundtrip_process.instances).to eq(51)
        expect(roundtrip_process.disk_quota).to eq(32)
        expect(roundtrip_process.space_guid).to eq(space.guid)
        expect(roundtrip_process.stack_guid).to eq(stack.guid)
        expect(roundtrip_process.state).to eq('STARTED')
        expect(roundtrip_process.command).to eq('start-command')
        expect(roundtrip_process.buildpack).to eq('buildpack')
        expect(roundtrip_process.health_check_timeout).to eq(3)
        expect(roundtrip_process.docker_image).to eq('docker_image:latest')
        expect(roundtrip_process.environment_json).to eq('env_json')
      end
    end
  end
end
