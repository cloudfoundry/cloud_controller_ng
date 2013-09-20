require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppPackage do
    include_context "resource pool"
    before do
      pending "This class is going away. Soon"
    end

    let(:tmpdir) { Dir.mktmpdir }
    let(:config_tmpdir) { File.join(tmpdir, "configured_tmp_dir") }

    before do
      FileUtils.mkdir(config_tmpdir)
      AppPackage.configure(
        :packages => {
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          }
        },
        :directories => { :tmpdir => config_tmpdir }
      )
      Fog.mock!
    end

    after do
      FileUtils.rm_rf(tmpdir)
    end

    describe 'unzipped_size' do
      it "should raise an instance of AppPackageInvalid if unzip exits with a nonzero status" do
        invalid_zip = Tempfile.new("unzipped_size_test")
        expect {
          AppPackage.unzipped_size(invalid_zip)
        }.to raise_error(Errors::AppPackageInvalid, /failed listing/)
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

        expect {
          AppPackage.validate_package_size(File.new(zipname), [])
        }.to raise_error(Errors::AppPackageInvalid, /exceeds/)
      end

      it "should raise an instance of AppPackageInvalid if the total size is too large" do
        tf = Tempfile.new("mytemp")
        tf.write("A" * 1024)
        tf.close

        ResourcePool.instance.add_path(tf.path)
        sha1 = Digest::SHA1.file(tf.path).hexdigest
        zipname = File.join(tmpdir, "test.zip")
        unzipped_size = create_zip(zipname, 1, 1024)
        AppPackage.max_droplet_size = unzipped_size + 512

        expect {
          AppPackage.validate_package_size(File.new(zipname),
                                           [{"sha1" => sha1, "fn" => "test/path"}])
        }.to raise_error(Errors::AppPackageInvalid, /exceeds/)
      end
    end

    describe "unpack_upload" do
      it "should raise an instance of AppPackageInvalid if unzip exits with a nonzero status code" do
        invalid_zip = Tempfile.new("app_package_test")
        expect {
          AppPackage.unpack_upload(File.new(invalid_zip))
        }.to raise_error(Errors::AppPackageInvalid, /unzipping/)
      end
    end

    describe "create_dir_skeleton" do
      let(:working_dir) { Dir.mktmpdir }

      after :each do
        FileUtils.rm_rf(working_dir)
      end

      it "should raise an error if the resource points outside of the app" do
        [ "../outside", "../../outside", "../././../outside"].each do |resource|
          expect {
            AppPackage.create_dir_skeleton("/a/b", resource)
          }.to raise_error(Errors::AppPackageInvalid, /points outside/)
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
        expect {
          AppPackage.resolve_path(tmpdir, "../foo")
        }.to raise_error(Errors::AppPackageInvalid, /resource path/)
      end

      it "should fail if the given path contains a symlink that points outside of the applications directory" do
        Dir.chdir(tmpdir) {
          File.symlink("/etc", "foo")
        }

        expect {
          AppPackage.resolve_path(tmpdir, "foo/bar")
        }.to raise_error(Errors::AppPackageInvalid, /resource path/)
      end
    end

    describe "repack_app_in" do
      it "should raise an instance of AppPackageInvalid if zipping the application fails" do
        nonexistant_dir = Dir.mktmpdir
        FileUtils.rm_rf(nonexistant_dir)
        expect {
          AppPackage.repack_app_in(nonexistant_dir, nonexistant_dir)
        }.to raise_error(Errors::AppPackageInvalid, /repacking/)
      end
    end

    describe ".to_zip" do
      before { pending "not used for real code" }

      let(:guid) { Sham.guid }

      def self.it_packages(expected_file_paths)
        def packaged_app_file
          file_key = AppPackage.key_from_guid(guid)
          file = AppPackage.blobstore.files.get(file_key)
          Tempfile.new("package").tap do |f|
            f.write(file.body)
            f.close
          end
        end

        it "moves the app package to the droplets directory" do
          expect {
            AppPackage.to_zip(guid, resources, zip_file)
          }.to change { AppPackage.package_exists?(guid) }.to(true)
        end

        it "packages correct files" do
          AppPackage.to_zip(guid, resources, zip_file)
          # do not inline this - otherwise the temp file might be GCed, which removes the files from disk before the assertion
          f = packaged_app_file
          list_files(unzip_zip(f.path)).should =~ expected_file_paths
        end

        it "packages in temporary directory specified in config" do
          AppPackage.should_receive(:repack_app_in).with(anything, /#{config_tmpdir}\/app/).and_call_original
          AppPackage.to_zip(guid, resources, zip_file)
        end
      end

      def self.it_raises_error
        it "raises error" do
          expect {
            AppPackage.to_zip(guid, resources, nil)
          }.to raise_error(Errors::AppPackageInvalid, /app package is invalid/)
        end
      end

      context "when the app does not need any file from resource pool" do
        let(:resources) { [] }

        context "when zip file was provided (with files)" do
          let(:zip_file) { create_zip_with_named_files(:file_count => 2, :file_size => 2048) }
          it_packages %w(ziptest_0 ziptest_1)
        end

        context "when the app has hidden files" do
          let(:zip_file) { create_zip_with_named_files(:file_count => 2, :hidden_file_count => 2, :file_size => 2048) }
          it_packages %w(ziptest_0 ziptest_1 .ziptest_0 .ziptest_1)
        end

        context "when zip file was not provided" do
          let(:zip_file) { nil }
          it_raises_error
        end
      end

      context "when the app needs some files from resource pool" do
        include_context "with valid resource in resource pool"
        let(:resources) { [valid_resource] }

        context "when zip file was provided (with files)" do
          let(:zip_file) { create_zip_with_named_files(:file_count => 2, :file_size => 2048) }
          it_packages %w(ziptest_0 ziptest_1 file/path)
        end

        context "when the app has hidden files" do
          let(:zip_file) { create_zip_with_named_files(:file_count => 2, :hidden_file_count => 2, :file_size => 2048) }
          it_packages %w(ziptest_0 ziptest_1 .ziptest_0 .ziptest_1 file/path)
        end

        context "when zip file was not provided" do
          let(:zip_file) { nil }
          it_packages %w(file/path)
        end
      end
    end

    describe "delete_droplet" do
      before { AppPackage.unstub(:delete_package) }

      it "should do nothing if the app package does not exist" do
        guid = Sham.guid

        # It is hard to test this via Fog, but lets at least make sure that it
        # doesn't throw an exception
        AppPackage.package_exists?(guid).should == false
        AppPackage.delete_package(guid)
        AppPackage.package_exists?(guid).should == false
      end

      it "should delete the droplet if it exists" do
        guid = Sham.guid

        create_app_package(guid)

        AppPackage.delete_package(guid)
        AppPackage.package_exists?(guid).should == false
      end
    end

    describe "package_uri" do
      
      context "fog AWS" do      
        before do
          @guid = Sham.guid

          AppPackage.configure(
            :packages => {
              :fog_connection => {
                :provider => "AWS",
                :aws_access_key_id => "fake_aws_key_id",
                :aws_secret_access_key => "fake_secret_access_key",
              }
            }
          )
          Fog.mock!

          create_app_package(@guid)
          
          FileUtils.rm_rf(tmpdir)
        end

        it "should return a URL for a valid guid" do
          uri = AppPackage.package_uri(@guid)
          uri.should match(/https:\/\/.*s3.amazonaws.com\/.*/)
        end

        it "should return nil for an invalid guid" do
          uri = AppPackage.package_uri(Sham.guid)
          uri.should be_nil
        end
        
        it "should not call a file's public_url method if there's a url method" do
          Fog::Storage::AWS::File.any_instance.should_not_receive(:public_url)
          uri = AppPackage.package_uri(@guid)
        end        
      end
      
      context "fog non-AWS" do      
        before do
          @guid = Sham.guid

          AppPackage.configure(
            :packages => {
              :fog_connection => {
                :provider => 'HP',
                :hp_access_key => "fake_credentials",
                :hp_secret_key => "fake_credentials",
                :hp_tenant_id => "fake_credentials",
                :hp_auth_uri =>  'https://auth.example.com:5000/v2.0/',
                :hp_use_upass_auth_style => true,
                :hp_avl_zone => 'nova'
              }
            }
          )
          Fog.mock!

          create_app_package(@guid)
          
          FileUtils.rm_rf(tmpdir)
        end
        
        it "should call a file's public_url method if there's no url method" do
          Fog::Storage::HP::File.any_instance.should_receive(:public_url)
          uri = AppPackage.package_uri(@guid)
        end

        it "should return nil for an invalid guid" do
          uri = AppPackage.package_uri(Sham.guid)
          uri.should be_nil
        end
      end
    end    
  end
  
  def create_app_package(guid)
    AppPackage.package_exists?(guid).should == false
    zipname = File.join(tmpdir, "test.zip")
    create_zip(zipname, 10, 1024)
    AppPackage.to_zip(guid, [], File.new(zipname))
    AppPackage.package_exists?(guid).should == true     
  end
end
