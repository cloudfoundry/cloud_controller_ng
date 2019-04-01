require 'benchmark'
require 'find'
require 'zip'

module VCAP::CloudController
  module Benchmark
    class Blobstore
      def perform
        resource_dir = generate_resources

        resource_timing = resource_match(resource_dir)
        puts "resource match timing: #{resource_timing * 1000}ms"

        zip_output_dir = Dir.mktmpdir
        zip_file = zip_resources(resource_dir, zip_output_dir)

        package_guid, resource_timing = upload_package(zip_file)
        puts "package upload timing: #{resource_timing * 1000}ms"

        resource_timing = download_package(package_guid, resource_dir)
        puts "package download timing: #{resource_timing * 1000}ms"

        bytes_read, resource_timing = download_buildpacks(resource_dir)
        puts "downloaded #{Buildpack.count} buildpacks, total #{bytes_read} bytes read"
        puts "buildpack download timing: #{resource_timing * 1000}ms"

        droplet_guid, resource_timing = upload_droplet(zip_file)
        puts "droplet upload timing: #{resource_timing * 1000}ms"

        resource_timing = download_droplet(droplet_guid, resource_dir)
        puts "droplet download timing: #{resource_timing * 1000}ms"

        big_droplet_file = Tempfile.new('big-droplet', resource_dir)
        big_droplet_file.write('abc' * 1024 * 1024 * 100)
        big_droplet_guid, resource_timing = upload_droplet(big_droplet_file.path)
        puts "big droplet upload timing: #{resource_timing * 1000}ms"

        resource_timing = download_droplet(big_droplet_guid, resource_dir)
        puts "big droplet download timing: #{resource_timing * 1000}ms"
      ensure
        FileUtils.remove_dir(resource_dir, true)
        FileUtils.remove_dir(zip_output_dir, true)
        package_blobstore_client.delete(package_guid) if package_guid
        droplet_blobstore_client.delete(droplet_guid) if droplet_guid
        droplet_blobstore_client.delete(big_droplet_guid) if big_droplet_guid
      end

      def resource_match(dir_path)
        resources = Find.find(dir_path).
                    select { |f| File.file?(f) }.
                    map { |f| { 'size' => File.stat(f).size, 'sha1' => Digester.new.digest_path(f) } }

        ::Benchmark.realtime do
          resource_pool.match_resources(resources)
        end
      end

      def upload_package(package_path)
        copy_to_blobstore(package_path, package_blobstore_client)
      end

      def download_package(package_guid, tmp_dir)
        tempfile = Tempfile.new('package-download-benchmark', tmp_dir)
        ::Benchmark.realtime do
          package_blobstore_client.download_from_blobstore(package_guid, tempfile.path)
        end
      end

      def download_buildpacks(tmp_dir)
        tempfile = Tempfile.new('buildpack-download-benchmark', tmp_dir)
        bytes_read = 0

        timing = ::Benchmark.realtime do
          bytes_read = Buildpack.map { |buildpack|
            buildpack_blobstore_client.download_from_blobstore(buildpack.key, tempfile.path)
            File.stat(tempfile.path).size
          }.sum
        end

        [bytes_read, timing]
      end

      def upload_droplet(droplet_path)
        copy_to_blobstore(droplet_path, droplet_blobstore_client)
      end

      def download_droplet(droplet_guid, tmp_dir)
        tempfile = Tempfile.new('droplet-download-benchmark', tmp_dir)

        ::Benchmark.realtime do
          droplet_blobstore_client.download_from_blobstore(droplet_guid, tempfile.path)
        end
      end

      private

      def generate_resources
        dir = Dir.mktmpdir

        100.times.each do |i|
          f = File.open(File.join(dir, i.to_s), 'w')
          f.write('foo' * (65536 + i))
        end

        dir
      end

      def zip_resources(resource_dir, output_dir)
        zip_file = File.join(output_dir, 'zipped_package')
        Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
          Find.find(resource_dir).
            select { |f| File.file?(f) }.
            each do |file|
            zipfile.add(File.basename(file), file)
          end
        end
        zip_file
      end

      def copy_to_blobstore(path, client)
        guid = SecureRandom.uuid

        timing = ::Benchmark.realtime do
          client.cp_to_blobstore(path, guid)
        end

        [guid, timing]
      end

      def buildpack_blobstore_client
        @buildpack_blobstore_client ||= CloudController::DependencyLocator.instance.buildpack_blobstore
      end

      def droplet_blobstore_client
        @droplet_blobstore_client ||= CloudController::DependencyLocator.instance.droplet_blobstore
      end

      def package_blobstore_client
        @package_blobstore_client ||= CloudController::DependencyLocator.instance.package_blobstore
      end

      def resource_pool
        ResourcePool.instance
      end
    end
  end
end
