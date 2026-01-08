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

        benchmark_packages(zip_file, resource_dir)
        benchmark_buildpacks(resource_dir)
        benchmark_droplets(zip_file, resource_dir)
        benchmark_big_droplets(resource_dir)
      ensure
        cleanup(resource_dir, zip_output_dir)
      end

      def resource_match(dir_path)
        resources = Find.find(dir_path).
                    select { |f| File.file?(f) }.
                    map { |f| { 'size' => File.stat(f).size, 'sha1' => Digester.new.digest_path(f) } }

        ::Benchmark.realtime do
          resource_pool.match_resources(resources)
        end
      end

      def upload_package(package_path, client=package_blobstore_client)
        copy_to_blobstore(package_path, client)
      end

      def download_package(package_guid, tmp_dir, client=package_blobstore_client)
        tempfile = Tempfile.new('package-download-benchmark', tmp_dir)
        ::Benchmark.realtime do
          client.download_from_blobstore(package_guid, tempfile.path)
        end
      end

      def download_buildpacks(tmp_dir, client=buildpack_blobstore_client)
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

      def upload_droplet(droplet_path, client=droplet_blobstore_client)
        copy_to_blobstore(droplet_path, client)
      end

      def download_droplet(droplet_guid, tmp_dir, client=droplet_blobstore_client)
        tempfile = Tempfile.new('droplet-download-benchmark', tmp_dir)

        ::Benchmark.realtime do
          client.download_from_blobstore(droplet_guid, tempfile.path)
        end
      end

      def benchmark_packages(zip_file, resource_dir)
        fog_guid, fog_time = upload_package(zip_file, package_blobstore_client)
        cli_guid, cli_time = upload_package(zip_file, package_blobstore_client_storage_cli)

        puts("package upload timing fog: #{fog_time * 1000}ms")
        puts("package upload timing storage-cli: #{cli_time * 1000}ms")

        fog_dl = download_package(fog_guid, resource_dir, package_blobstore_client)
        cli_dl = download_package(cli_guid, resource_dir, package_blobstore_client_storage_cli)

        puts("package download timing fog: #{fog_dl * 1000}ms")
        puts("package download timing storage-cli: #{cli_dl * 1000}ms")

        remember_cleanup(:package, fog_guid, cli_guid)
      end

      def benchmark_buildpacks(resource_dir)
        fog_bytes, fog_time = download_buildpacks(resource_dir, buildpack_blobstore_client)
        cli_bytes, cli_time = download_buildpacks(resource_dir, buildpack_blobstore_client_storage_cli)

        puts("downloaded #{Buildpack.count} buildpacks, total fog #{fog_bytes} bytes read")
        puts("downloaded #{Buildpack.count} buildpacks, total storage-cli #{cli_bytes} bytes read")
        puts("buildpack download timing fog: #{fog_time * 1000}ms")
        puts("buildpack download timing storage-cli: #{cli_time * 1000}ms")
      end

      def benchmark_droplets(zip_file, resource_dir)
        fog_guid, fog_time = upload_droplet(zip_file, droplet_blobstore_client)
        cli_guid, cli_time = upload_droplet(zip_file, droplet_blobstore_client_storage_cli)

        puts("droplet upload timing fog: #{fog_time * 1000}ms")
        puts("droplet upload timing storage-cli: #{cli_time * 1000}ms")

        fog_dl = download_droplet(fog_guid, resource_dir, droplet_blobstore_client)
        cli_dl = download_droplet(cli_guid, resource_dir, droplet_blobstore_client_storage_cli)

        puts("droplet download timing fog: #{fog_dl * 1000}ms")
        puts("droplet download timing storage-cli: #{cli_dl * 1000}ms")

        remember_cleanup(:droplet, fog_guid, cli_guid)
      end

      def benchmark_big_droplets(resource_dir)
        fog_guid, fog_time = upload_big_droplet(resource_dir, droplet_blobstore_client)
        cli_guid, cli_time = upload_big_droplet(resource_dir, droplet_blobstore_client_storage_cli)

        puts("big droplet upload timing fog: #{fog_time * 1000}ms")
        puts("big droplet upload timing storage-cli: #{cli_time * 1000}ms")

        fog_dl = download_droplet(fog_guid, resource_dir, droplet_blobstore_client)
        cli_dl = download_droplet(cli_guid, resource_dir, droplet_blobstore_client_storage_cli)

        puts("big droplet download timing fog: #{fog_dl * 1000}ms")
        puts("big droplet download timing storage-cli: #{cli_dl * 1000}ms")

        remember_cleanup(:droplet, fog_guid, cli_guid)
      end

      def remember_cleanup(type, fog_guid, cli_guid)
        cleanup_items << [type, fog_guid, cli_guid]
      end

      def cleanup(resource_dir, zip_output_dir)
        FileUtils.remove_dir(resource_dir, true)
        FileUtils.remove_dir(zip_output_dir, true)

        cleanup_items.each do |type, fog_guid, cli_guid|
          client_fog, client_cli =
            case type
            when :package then [package_blobstore_client, package_blobstore_client_storage_cli]
            when :droplet then [droplet_blobstore_client, droplet_blobstore_client_storage_cli]
            end

          client_fog.delete(fog_guid) if fog_guid
          client_cli.delete(cli_guid) if cli_guid
        end
      end

      def cleanup_items
        @cleanup_items ||= []
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
        @buildpack_blobstore_client ||= CloudController::DependencyLocator.instance.buildpack_blobstore(blobstore_type: 'fog')
      end

      def buildpack_blobstore_client_storage_cli
        @buildpack_blobstore_client_storage_cli ||= CloudController::DependencyLocator.instance.buildpack_blobstore(blobstore_type: 'storage-cli')
      end

      def droplet_blobstore_client
        @droplet_blobstore_client ||= CloudController::DependencyLocator.instance.droplet_blobstore(blobstore_type: 'fog')
      end

      def droplet_blobstore_client_storage_cli
        @droplet_blobstore_client_storage_cli ||= CloudController::DependencyLocator.instance.droplet_blobstore(blobstore_type: 'storage-cli')
      end

      def package_blobstore_client
        @package_blobstore_client ||= CloudController::DependencyLocator.instance.package_blobstore(blobstore_type: 'fog')
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
