require 'spec_helper'

module VCAP::CloudController
  RSpec.describe InstallBuildpacks do
    describe 'installs buildpacks' do
      let(:installer) { InstallBuildpacks.new(TestConfig.config_instance) }
      let(:job) { instance_double(Jobs::Runtime::BuildpackInstaller) }
      let(:job2) { instance_double(Jobs::Runtime::BuildpackInstaller) }
      let(:job3) { instance_double(Jobs::Runtime::BuildpackInstaller) }
      let(:enqueuer) { instance_double(Jobs::Enqueuer) }
      let(:install_buildpack_config) do
        {
          install_buildpacks: [
            {
              'name' => 'buildpack1',
              'package' => 'mybuildpackpkg'
            },
          ]
        }
      end

      before do
        TestConfig.override(install_buildpack_config)
        allow(job).to receive(:perform)
      end

      describe 'installing buildpacks' do
        context 'where there are no buildpacks to install' do
          let(:install_buildpack_config) { { install_buildpacks: [] } }

          it 'does nothing and does not raise any errors' do
            expect {
              installer.install(TestConfig.config[:install_buildpacks])
            }.to_not raise_error
          end
        end

        context 'when there are multiple buildpacks' do
          before do
            expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').and_return(['abuildpack.zip'])
            expect(File).to receive(:file?).with('abuildpack.zip').and_return(true)
            expect(Dir).to receive(:[]).with('/var/vcap/packages/myotherpkg/*.zip').and_return(['otherbp.zip'])
            expect(File).to receive(:file?).with('otherbp.zip').and_return(true)
            expect(Dir).to receive(:[]).with('/var/vcap/packages/myotherpkg2/*.zip').and_return(['otherbp2.zip'])
            expect(File).to receive(:file?).with('otherbp2.zip').and_return(true)

            TestConfig.config[:install_buildpacks].concat [
              { 'name' => 'buildpack2', 'package' => 'myotherpkg' },
              { 'name' => 'buildpack3', 'package' => 'myotherpkg2' },
            ]

            expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack1', 'abuildpack.zip', {}).and_return(job)
            allow(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack2', 'otherbp.zip', {}).and_return(job2)
            allow(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack3', 'otherbp2.zip', {}).and_return(job3)
            allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
          end

          it 'tries to install the first buildpack in-process (canary)' do
            expect(job).to receive(:perform).exactly(1).times

            expect(enqueuer).to receive(:enqueue).twice
            expect(job2).not_to receive(:perform)
            expect(job3).not_to receive(:perform)

            installer.install(TestConfig.config[:install_buildpacks])
          end

          context 'when the canary successfully installs' do
            it 'enqueues the rest of the buildpack install jobs' do
              allow(job).to receive(:perform)

              expect(Jobs::Enqueuer).to receive(:new).with(job2, queue: instance_of(Jobs::LocalQueue)).ordered.and_return(enqueuer)
              expect(Jobs::Enqueuer).to receive(:new).with(job3, queue: instance_of(Jobs::LocalQueue)).ordered.and_return(enqueuer)

              expect(enqueuer).to receive(:enqueue).twice

              installer.install(TestConfig.config[:install_buildpacks])
            end
          end

          context 'when the canary does not survive' do
            it 'does NOT enqueue any of the buildpack install jobs and raises an error' do
              allow(job).to receive(:perform).and_raise 'BOOM'

              expect(Jobs::Enqueuer).not_to receive(:new)

              expect {
                installer.install(TestConfig.config[:install_buildpacks])
              }.to raise_error 'BOOM'
            end
          end
        end
      end

      it 'logs an error when no buildpack zip file is found' do
        expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').and_return([])
        expect(installer.logger).to receive(:error).with(/No file found for the buildpack/)

        installer.install(TestConfig.config[:install_buildpacks])
      end

      context 'when no buildpacks defined' do
        it 'succeeds without failure' do
          installer.install(nil)
        end
      end

      context 'override file location' do
        let(:install_buildpack_config) do
          {
            install_buildpacks: [
              {
                'name' => 'buildpack1',
                'package' => 'mybuildpackpkg',
                'file' => 'another.zip',
              },
            ]
          }
        end

        it 'uses the file override' do
          expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack1', 'another.zip', {}).and_return(job)
          expect(job).to receive(:perform)
          expect(File).to receive(:file?).with('another.zip').and_return(true)

          installer.install(TestConfig.config[:install_buildpacks])
        end

        it 'fails when no buildpack zip file is found' do
          expect(installer.logger).to receive(:error).with(/File not found: another.zip/)

          installer.install(TestConfig.config[:install_buildpacks])
        end

        it 'succeeds when no package is specified' do
          TestConfig.config[:install_buildpacks][0].delete('package')

          expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack1', 'another.zip', {}).and_return(job)
          expect(job).to receive(:perform)
          expect(File).to receive(:file?).with('another.zip').and_return(true)

          installer.install(TestConfig.config[:install_buildpacks])
        end
      end

      context 'missing required values' do
        it 'fails when no package is specified' do
          TestConfig.config[:install_buildpacks][0].delete('package')
          expect(installer.logger).to receive(:error).with(/A package or file must be specified/)

          installer.install(TestConfig.config[:install_buildpacks])
        end

        it 'fails when no name is specified' do
          TestConfig.config[:install_buildpacks][0].delete('name')
          expect(installer.logger).to receive(:error).with(/A name must be specified for the buildpack/)

          installer.install(TestConfig.config[:install_buildpacks])
        end
      end

      context 'additional options' do
        let(:install_buildpack_config) do
          {
            install_buildpacks: [
              {
                'name' => 'buildpack1',
                'package' => 'mybuildpackpkg',
                'enabled' => true,
                'locked' => false,
                'position' => 5,
              },
            ]
          }
        end

        it 'the config is valid' do
          TestConfig.config[:nginx][:instance_socket] = 'mysocket'
          Config.schema.validate(TestConfig.config)
        end

        it 'passes optional attributes to the job' do
          expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).
            with('buildpack1', 'abuildpack.zip', { enabled: true, locked: false, position: 5 }).and_return(job)
          expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').and_return(['abuildpack.zip'])
          expect(File).to receive(:file?).with('abuildpack.zip').and_return(true)

          installer.install(TestConfig.config[:install_buildpacks])
        end
      end
    end
  end
end
