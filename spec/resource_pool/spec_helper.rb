# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

module VCAP::CloudController::ResourcePoolSpecHelper
  shared_context "resource pool" do |klass = described_class|
    before(:all) do
      num_dirs = 3
      num_unique_allowed_files_per_dir = 7
      file_duplication_factor = 2
      max_file_size = 1098 # this is arbitrary

      @total_allowed_files =
          num_dirs * num_unique_allowed_files_per_dir * file_duplication_factor

      @dummy_descriptor = { "sha1" => Digest::SHA1.hexdigest("abc"), "size" => 1}
      @tmpdir = Dir.mktmpdir

      cfg = { :resource_pool => { :maximum_size => max_file_size }}
      klass.configure(cfg)

      @descriptors = []
      num_dirs.times do
        dirname = SecureRandom.uuid
        Dir.mkdir("#{@tmpdir}/#{dirname}")
        num_unique_allowed_files_per_dir.times do
          basename = SecureRandom.uuid
          path = "#{@tmpdir}/#{dirname}/#{basename}"
          contents = SecureRandom.uuid

          descriptor = {
            "sha1" => Digest::SHA1.hexdigest(contents),
            "size" => contents.length
          }
          @descriptors << descriptor

          file_duplication_factor.times do |i|
            File.open("#{path}-#{i}", "w") do |f|
              f.write contents
            end
          end

          File.open("#{path}-not-allowed", "w") do |f|
            f.write "A" * max_file_size
          end
        end
      end
    end

    after(:all) do
      FileUtils.rm_rf(@tmpdir)
    end
  end
end
