require 'benchmark'
require 'find'
require 'zip'

module VCAP::CloudController
  module Benchmark
    class Blobstore
      def perform
        resource_dir = generate_resources

        resource_timing = resource_match(resource_dir)
        puts("resource match timing: #{resource_timing * 1000}ms")

        zip_output_dir = Dir.mktmpdir
        zip_file = zip_resources(resource_dir, zip_output_dir)

        package_guid, resource_timing = upload_package(zip_file, package_blobstore_client)
        puts("package upload timing fog: #{resource_timing * 1000}ms")
        package_guid_cli, resource_timing_cli = upload_package(zip_file, package_blobstore_client_storage_cli)
        puts("package upload timing storage-cli: #{resource_timing_cli * 1000}ms")

        resource_timing = download_package(package_guid, resource_dir, package_blobstore_client)
        puts("package download timing fog: #{resource_timing * 1000}ms")
        resource_timing_cli = download_package(package_guid_cli, resource_dir, package_blobstore_client_storage_cli)
        puts("package download timing storage-cli: #{resource_timing_cli * 1000}ms")

        bytes_read, resource_timing = download_buildpacks(resource_dir, buildpack_blobstore_client)
        bytes_read_cli, resource_timing_cli = download_buildpacks(resource_dir, buildpack_blobstore_client_storage_cli)
        puts("downloaded #{Buildpack.count} buildpacks, total fog #{bytes_read} bytes read")
        puts("downloaded #{Buildpack.count} buildpacks, total storage-cli  #{bytes_read_cli} bytes read")
        puts("buildpack download timing fog: #{resource_timing * 1000}ms")
        puts("buildpack download timing storage-cli: #{resource_timing_cli * 1000}ms")

        droplet_guid, resource_timing = upload_droplet(zip_file, droplet_blobstore_client)
        puts("droplet upload timing fog: #{resource_timing * 1000}ms")
        droplet_guid_cli, resource_timing_cli = upload_droplet(zip_file, droplet_blobstore_client_storage_cli)
        puts("droplet upload timing storage-cli: #{resource_timing_cli * 1000}ms")

        resource_timing = download_droplet(droplet_guid, resource_dir, droplet_blobstore_client)
        puts("droplet download timing fog: #{resource_timing * 1000}ms")
        resource_timing_cli = download_droplet(droplet_guid_cli, resource_dir, droplet_blobstore_client_storage_cli)
        puts("droplet download timing storage-cli: #{resource_timing_cli * 1000}ms")

        big_droplet_file = Tempfile.new('big-droplet', resource_dir)
        big_droplet_file.write('abc' * 1024 * 1024 * 100)
        big_droplet_file.flush
        big_droplet_file.rewind
        big_droplet_guid, resource_timing = upload_droplet(big_droplet_file.path, droplet_blobstore_client)
        big_droplet_file_cli = Tempfile.new('big-droplet', resource_dir)
        big_droplet_file_cli.write('abc' * 1024 * 1024 * 100)
        big_droplet_file_cli.flush
        big_droplet_file_cli.rewind
        big_droplet_guid_cli, resource_timing_cli = upload_droplet(big_droplet_file_cli.path, droplet_blobstore_client_storage_cli)
        puts("big droplet upload timing fog: #{resource_timing * 1000}ms")
        puts("big droplet upload timing storage-cli: #{resource_timing_cli * 1000}ms")
        resource_timing = download_droplet(big_droplet_guid, resource_dir, droplet_blobstore_client)
        puts("big droplet download timing fog: #{resource_timing * 1000}ms")
        resource_timing_cli = download_droplet(big_droplet_guid_cli, resource_dir, droplet_blobstore_client_storage_cli)
        puts("big droplet download timing storage-cli: #{resource_timing_cli * 1000}ms")
      ensure
        FileUtils.remove_dir(resource_dir, true)
        FileUtils.remove_dir(zip_output_dir, true)
        big_droplet_file.close
        big_droplet_file_cli.close
        package_blobstore_client.delete(package_guid) if package_guid
        droplet_blobstore_client.delete(droplet_guid) if droplet_guid
        droplet_blobstore_client.delete(big_droplet_guid) if big_droplet_guid
        package_blobstore_client_storage_cli.delete(package_guid_cli) if package_guid_cli
        droplet_blobstore_client_storage_cli.delete(droplet_guid_cli) if droplet_guid_cli
        droplet_blobstore_client_storage_cli.delete(big_droplet_guid_cli) if big_droplet_guid_cli
      end

      def resource_match(dir_path)
        resources = Find.find(dir_path).
                    select { |f| File.file?(f) }.
                    map { |f| { 'size' => File.stat(f).size, 'sha1' => Digester.new.digest_path(f) } }

        ::Benchmark.realtime do
          resource_pool.match_resources(resources)
        end
      end

      def upload_package(package_path, client = package_blobstore_client)
        copy_to_blobstore(package_path, client)
      end

      def download_package(package_guid, tmp_dir, client = package_blobstore_client)
        tempfile = Tempfile.new('package-download-benchmark', tmp_dir)
        ::Benchmark.realtime do
          client.download_from_blobstore(package_guid, tempfile.path)
        end
      end

      def download_buildpacks(tmp_dir, client = buildpack_blobstore_client)
        tempfile = Tempfile.new('buildpack-download-benchmark', tmp_dir)
        bytes_read = 0

        timing = ::Benchmark.realtime do
          bytes_read = Buildpack.map do |buildpack|
            client.download_from_blobstore(buildpack.key, tempfile.path)
            File.stat(tempfile.path).size
          end.sum
        end

        [bytes_read, timing]
      end

      def upload_droplet(droplet_path, client = droplet_blobstore_client)
        copy_to_blobstore(droplet_path, client)
      end

      def download_droplet(droplet_guid, tmp_dir, client = droplet_blobstore_client)
        tempfile = Tempfile.new('droplet-download-benchmark', tmp_dir)

        ::Benchmark.realtime do
          client.download_from_blobstore(droplet_guid, tempfile.path)
        end
      end

      private

      def generate_resources
        dir = Dir.mktmpdir

        100.times.each do |i|
          f = File.open(File.join(dir, i.to_s), 'w')
          f.write('foo' * (65_536 + i))
        end

        dir
      end

      def zip_resources(resource_dir, output_dir)
        zip_file = File.join(output_dir, 'zipped_package')
        Zip::File.open(zip_file, create: true) do |zipfile|
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
        @buildpack_blobstore_client_fog ||= CloudController::DependencyLocator.instance.buildpack_blobstore(blobstore_type: 'fog')
      end

      def buildpack_blobstore_client_storage_cli
        @buildpack_blobstore_client_storage_cli ||= CloudController::DependencyLocator.instance.buildpack_blobstore(blobstore_type: 'storage-cli')
      end

      def droplet_blobstore_client
        @droplet_blobstore_client_fog ||= CloudController::DependencyLocator.instance.droplet_blobstore(blobstore_type: 'fog')
      end

      def droplet_blobstore_client_storage_cli
        @droplet_blobstore_client_storage_cli ||= CloudController::DependencyLocator.instance.droplet_blobstore(blobstore_type: 'storage-cli')
      end

      def package_blobstore_client
        @package_blobstore_client_fog ||= CloudController::DependencyLocator.instance.package_blobstore(blobstore_type: 'fog')
      end

      def package_blobstore_client_storage_cli
        @package_blobstore_client_storage_cli ||= CloudController::DependencyLocator.instance.package_blobstore(blobstore_type: 'storage-cli')
      end

      def resource_pool
        ResourcePool.instance
      end
    end
  end
end
