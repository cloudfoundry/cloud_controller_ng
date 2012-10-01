# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppPackage do
    let(:tmpdir) { Dir.mktmpdir }
    let(:droplets_dir) { Dir.mktmpdir }

    before do
      FilesystemPool.configure
      AppPackage.configure(:directories => { :droplets => droplets_dir })
    end

    after do
      FileUtils.rm_rf(tmpdir)
      FileUtils.rm_rf(droplets_dir)
    end

    describe 'unzipped_size' do
      it "should raise an instance of AppPackageInvalid if unzip exits with a nonzero status" do
        invalid_zip = Tempfile.new("unzipped_size_test")
        lambda {
          AppPackage.unzipped_size(invalid_zip)
        }.should raise_error(Errors::AppPackageInvalid, /failed listing/)
      end

      it "should return the total size of the unzipped droplet" do
        [1, 5].each do |file_count|
          zipname = File.join(tmpdir, "test#{file_count}.zip")
          unzipped_size = create_zip(zipname, file_count)
          computed_size = AppPackage.unzipped_size(File.new(zipname))
          computed_size.should == unzipped_size
        end
      end
    end

    describe "validate_package_size" do
      before do
        @saved_size = AppPackage.max_droplet_size
      end

      after :each do
        AppPackage.max_droplet_size = @saved_size
      end

      it "should raise an instance of AppPackageInvalid if the unzipped size is too large" do
        zipname = File.join(tmpdir, "test.zip")
        unzipped_size = create_zip(zipname, 10, 1024)
        AppPackage.max_droplet_size = unzipped_size - 1024

        lambda {
          AppPackage.validate_package_size(File.new(zipname), [])
        }.should raise_error(Errors::AppPackageInvalid, /exceeds/)
      end

      it "should raise an instance of AppPackageInvalid if the total size is too large" do
        tf = Tempfile.new("mytemp")
        tf.write("A" * 1024)
        tf.close

        AppPackage.resource_pool.add_path(tf.path)
        sha1 = Digest::SHA1.file(tf.path).hexdigest
        zipname = File.join(tmpdir, "test.zip")
        unzipped_size = create_zip(zipname, 1, 1024)
        AppPackage.max_droplet_size = unzipped_size + 512

        lambda {
          AppPackage.validate_package_size(File.new(zipname),
                                           [{"sha1" => sha1, "fn" => "test/path"}])
        }.should raise_error(Errors::AppPackageInvalid, /exceeds/)
      end
    end

    describe "unpack_upload" do
      it "should raise an instance of AppPackageInvalid if unzip exits with a nonzero status code" do
        invalid_zip = Tempfile.new("app_package_test")
        lambda {
          AppPackage.unpack_upload(File.new(invalid_zip))
        }.should raise_error(Errors::AppPackageInvalid, /unzipping/)
      end
    end

    describe "create_dir_skeleton" do
      let(:working_dir) { Dir.mktmpdir }

      after :each do
        FileUtils.rm_rf(working_dir)
      end

      it "should raise an error if the resource points outside of the app" do
        [ "../outside", "../../outside", "../././../outside"].each do |resource|
          lambda {
            AppPackage.create_dir_skeleton("/a/b", resource)
          }.should raise_error(Errors::AppPackageInvalid, /points outside/)
        end
      end

      it "should create the directory skeleton if the resource points inside the app" do
        ["foo/bar/baz.rb", "bar/../bar/baz/jaz.rb"].each do |resource|
          AppPackage.create_dir_skeleton(working_dir, resource)
        end

        File.directory?(File.join(working_dir, "foo/bar")).should be_true
        File.directory?(File.join(working_dir, "bar/baz")).should be_true
      end

      it "should not create a directory in the place of a file resource" do
        AppPackage.create_dir_skeleton(working_dir, "foo/bar/baz.rb")

        File.directory?(File.join(working_dir, "foo/bar/baz.rb")).should be_false
        File.exists?(File.join(working_dir, "foo/bar/baz.rb")).should be_false
      end
    end

    describe "#resolve_path" do
      let(:dummy_zip) { Tempfile.new("app_package_test") }

      it "should succeed if the given path points to a file in the apps directory" do
        testpath = File.join(tmpdir, "testfile")
        File.new(testpath, "w+")
        AppPackage.resolve_path(tmpdir, "testfile").should == File.realdirpath(testpath)
      end

      it "should fail if the given path does not resolve to a file in the applications directory" do
        lambda {
          AppPackage.resolve_path(tmpdir, "../foo")
        }.should raise_error(Errors::AppPackageInvalid, /resource path/)
      end

      it "should fail if the given path contains a symlink that points outside of the applications directory" do
        Dir.chdir(tmpdir) {
          File.symlink("/etc", "foo")
        }

        lambda {
          AppPackage.resolve_path(tmpdir, "foo/bar")
        }.should raise_error(Errors::AppPackageInvalid, /resource path/)
      end
    end

    describe "repack_app_in" do
      it "should raise an instance of AppPackageInvalid if zipping the application fails" do
        nonexistant_dir = Dir.mktmpdir
        FileUtils.rm_rf(nonexistant_dir)
        lambda {
          AppPackage.repack_app_in(nonexistant_dir, nonexistant_dir)
        }.should raise_error(Errors::AppPackageInvalid, /repacking/)
      end
    end

    describe "to_zip" do
      it "should move the app package to the droplets directory" do
        guid = "abc"
        zipname = File.join(tmpdir, "test.zip")
        create_zip(zipname, 10, 1024)
        AppPackage.to_zip(guid, File.new(zipname), [])
        File.exist?(AppPackage.package_path(guid)).should == true
      end
    end

    describe "delete_droplet" do
      it "should do nothing if the app package does not exist" do
        File.should_receive(:exists?).and_return(false)
        File.should_not_receive(:delete)
        AppPackage.delete_package("some_guid")
      end

      it "should delete the droplet if it exists" do
        File.should_receive(:exists?).and_return(true)
        File.should_receive(:delete).with(AppPackage.package_path("some_guid"))
        AppPackage.delete_package("some_guid")
      end
    end
  end
end
