require 'spec_helper'

module VCAP::CloudController
  RSpec.describe InstallBuildpacks do
    describe 'installs buildpacks' do
      let(:installer) { InstallBuildpacks.new(TestConfig.config) }
      let(:job) { double(Jobs::Runtime::BuildpackInstaller) }
      let(:job2) { double(Jobs::Runtime::BuildpackInstaller) }
      let(:enqueuer) { double(Jobs::Enqueuer) }
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
      end

      it 'enqueues a job to install a buildpack' do
        expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack1', 'abuildpack.zip', {}).and_return(job)
        expect(Jobs::Enqueuer).to receive(:new).with(job, queue: instance_of(Jobs::LocalQueue)).and_return(enqueuer)
        expect(enqueuer).to receive(:enqueue)
        expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').and_return(['abuildpack.zip'])
        expect(File).to receive(:file?).with('abuildpack.zip').and_return(true)

        installer.install(TestConfig.config[:install_buildpacks])
      end

      it 'handles multiple buildpacks' do
        TestConfig.config[:install_buildpacks] << {
          'name' => 'buildpack2',
          'package' => 'myotherpkg'
        }

        expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack1', 'abuildpack.zip', {}).ordered.and_return(job)
        expect(Jobs::Enqueuer).to receive(:new).with(job, queue: instance_of(Jobs::LocalQueue)).ordered.and_return(enqueuer)
        expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').and_return(['abuildpack.zip'])
        expect(File).to receive(:file?).with('abuildpack.zip').and_return(true)

        expect(Jobs::Runtime::BuildpackInstaller).to receive(:new).with('buildpack2', 'otherbp.zip', {}).ordered.and_return(job2)
        expect(Jobs::Enqueuer).to receive(:new).with(job2, queue: instance_of(Jobs::LocalQueue)).ordered.and_return(enqueuer)
        expect(Dir).to receive(:[]).with('/var/vcap/packages/myotherpkg/*.zip').and_return(['otherbp.zip'])
        expect(File).to receive(:file?).with('otherbp.zip').and_return(true)

        expect(enqueuer).to receive(:enqueue).twice

        installer.install(TestConfig.config[:install_buildpacks])
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
          expect(Jobs::Enqueuer).to receive(:new).with(job, queue: instance_of(Jobs::LocalQueue)).and_return(enqueuer)
          expect(enqueuer).to receive(:enqueue)
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
          expect(Jobs::Enqueuer).to receive(:new).with(job, queue: instance_of(Jobs::LocalQueue)).and_return(enqueuer)
          expect(enqueuer).to receive(:enqueue)
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
