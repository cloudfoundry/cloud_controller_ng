require "spec_helper"

module VCAP::CloudController
  describe InstallBuildpacks do

    describe "installs buildpacks" do

      let (:installer) { InstallBuildpacks.new(config) }
      let (:job) { double(Jobs::Runtime::BuildpackInstaller) }
      let (:job2) { double(Jobs::Runtime::BuildpackInstaller) }
      let (:enqueuer) { double(Jobs::Enqueuer) }
      let (:install_buildpack_config) do
        {
          :install_buildpacks=>[
            {
              "name"=>"buildpack1",
              "package"=>"mybuildpackpkg"
            },
          ]
        }
      end

      before do
        @old_config = config
        config_override(install_buildpack_config)
      end

      after do
        config_override(@old_config)
      end


      it "enqueues a job to install a buildpack" do
        Jobs::Runtime::BuildpackInstaller.should_receive(:new).with("buildpack1", "abuildpack.zip", {}).and_return(job)
        Jobs::Enqueuer.should_receive(:new).with(job, queue: instance_of(LocalQueue)).and_return(enqueuer)
        enqueuer.should_receive(:enqueue)
        Dir.should_receive(:[]).with("/var/vcap/packages/mybuildpackpkg/*.zip").and_return(["abuildpack.zip"])
        File.should_receive(:file?).with("abuildpack.zip").and_return(true)

        installer.install(config[:install_buildpacks])
      end

      it "handles multiple buildpacks" do
        config[:install_buildpacks] << {
          "name"=>"buildpack2",
          "package"=>"myotherpkg"
        }

        Jobs::Runtime::BuildpackInstaller.should_receive(:new).with("buildpack1", "abuildpack.zip", {}).ordered.and_return(job)
        Jobs::Enqueuer.should_receive(:new).with(job, queue: instance_of(LocalQueue)).ordered.and_return(enqueuer)
        Dir.should_receive(:[]).with("/var/vcap/packages/mybuildpackpkg/*.zip").and_return(["abuildpack.zip"])
        File.should_receive(:file?).with("abuildpack.zip").and_return(true)

        Jobs::Runtime::BuildpackInstaller.should_receive(:new).with("buildpack2", "otherbp.zip", {}).ordered.and_return(job2)
        Jobs::Enqueuer.should_receive(:new).with(job2, queue: instance_of(LocalQueue)).ordered.and_return(enqueuer)
        Dir.should_receive(:[]).with("/var/vcap/packages/myotherpkg/*.zip").and_return(["otherbp.zip"])
        File.should_receive(:file?).with("otherbp.zip").and_return(true)

        enqueuer.should_receive(:enqueue).twice

        installer.install(config[:install_buildpacks])
      end

      it "logs an error when no buildpack zip file is found" do
        Dir.should_receive(:[]).with("/var/vcap/packages/mybuildpackpkg/*.zip").and_return([])
        installer.logger.should_receive(:error).with(/No file found for the buildpack/)

        installer.install(config[:install_buildpacks])
      end

      context "when no buildpacks defined" do
        it "succeeds without failure" do
          installer.install(nil)
        end
      end

      context "override file location" do
        let (:install_buildpack_config) do
          {
            :install_buildpacks=>[
              {
                "name"=>"buildpack1",
                "package"=>"mybuildpackpkg",
                "file"=>"another.zip",
              },
            ]
          }
        end

        it "uses the file override" do
          Jobs::Runtime::BuildpackInstaller.should_receive(:new).with("buildpack1", "another.zip", {}).and_return(job)
          Jobs::Enqueuer.should_receive(:new).with(job, queue: instance_of(LocalQueue)).and_return(enqueuer)
          enqueuer.should_receive(:enqueue)
          File.should_receive(:file?).with("another.zip").and_return(true)

          installer.install(config[:install_buildpacks])
        end

        it "fails when no buildpack zip file is found" do
          installer.logger.should_receive(:error).with(/File not found: another.zip/)

          installer.install(config[:install_buildpacks])
        end

        it "succeeds when no package is specified" do
          config[:install_buildpacks][0].delete("package")

          Jobs::Runtime::BuildpackInstaller.should_receive(:new).with("buildpack1", "another.zip", {}).and_return(job)
          Jobs::Enqueuer.should_receive(:new).with(job, queue: instance_of(LocalQueue)).and_return(enqueuer)
          enqueuer.should_receive(:enqueue)
          File.should_receive(:file?).with("another.zip").and_return(true)

          installer.install(config[:install_buildpacks])
        end
      end

      context "missing required values" do
        it "fails when no package is specified" do
          config[:install_buildpacks][0].delete("package")
          installer.logger.should_receive(:error).with(/A package or file must be specified/)

          installer.install(config[:install_buildpacks])
        end

        it "fails when no name is specified" do
          config[:install_buildpacks][0].delete("name")
          installer.logger.should_receive(:error).with(/A name must be specified for the buildpack/)

          installer.install(config[:install_buildpacks])
        end
      end

      context "additional options" do
        let (:install_buildpack_config) do
          {
            :install_buildpacks=>[
              {
                "name"=>"buildpack1",
                "package"=>"mybuildpackpkg",
                "enabled"=>true,
                "locked"=>false,
                "position"=>5,
              },
            ]
          }
        end

        it "the config is valid" do
          config[:nginx][:instance_socket] = "mysocket"
          Config.schema.validate(config)
        end

        it "passes optional attributes to the job" do
          Jobs::Runtime::BuildpackInstaller.should_receive(:new).
            with("buildpack1", "abuildpack.zip",{:enabled => true, :locked =>false, :position=>5}).and_return(job)
          Dir.should_receive(:[]).with("/var/vcap/packages/mybuildpackpkg/*.zip").and_return(["abuildpack.zip"])
          File.should_receive(:file?).with("abuildpack.zip").and_return(true)

          installer.install(config[:install_buildpacks])
        end
      end
    end
  end
end
