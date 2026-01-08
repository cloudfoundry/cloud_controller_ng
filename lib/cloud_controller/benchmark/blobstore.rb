# frozen_string_literal: true

require 'benchmark'
require 'find'
require 'zip'
require 'tempfile'
require 'fileutils'
require 'securerandom'

module VCAP::CloudController
  module Benchmark
    class Blobstore
      SIZES = [
        ['0.005MB', (0.005 * 1024 * 1024).to_i],
        ['0.01MB',  (0.01  * 1024 * 1024).to_i],
        ['0.1MB',   (0.1   * 1024 * 1024).to_i],
        ['1MB',     1    * 1024 * 1024],
        ['10MB',    10   * 1024 * 1024],
        ['100MB',   100  * 1024 * 1024],
        ['200MB',   200  * 1024 * 1024],
        ['300MB',   300  * 1024 * 1024],
        ['400MB',   400  * 1024 * 1024],
        ['500MB',   500  * 1024 * 1024],
        ['600MB',   600  * 1024 * 1024],
        ['700MB',   700  * 1024 * 1024],
        ['800MB',   800  * 1024 * 1024],
        ['900MB',   900  * 1024 * 1024],
        ['1000MB',  1000 * 1024 * 1024]
      ].freeze

      CHUNK_1MB = '0'.b * (1024 * 1024)

      def perform
        big_droplet_guids = []
        resource_dir = generate_resources
        log_timing('resource match timing', resource_match(resource_dir))

        zip_output_dir = Dir.mktmpdir
        zip_file = zip_resources(resource_dir, zip_output_dir)

        package_guid, timing = upload_package(zip_file)
        log_timing('package upload timing', timing)
        log_timing('package download timing', download_package(package_guid, resource_dir))

        bytes_read, timing = download_buildpacks(resource_dir)
        puts("downloaded #{Buildpack.count} buildpacks, total #{bytes_read} bytes read")
        log_timing('buildpack download timing', timing)

        droplet_results = []

        SIZES.each do |label, bytes|
          Tempfile.create(["big-droplet-#{label}", '.bin'], resource_dir) do |tempfile|
            write_file_of_size(tempfile.path, bytes)

            guid, upload_timing = upload_droplet(tempfile.path)
            big_droplet_guids << guid
            droplet_results << { label: "droplet #{label}", guid: guid, upload_timing: upload_timing }
          end
        end
        # rubocop:disable Style/CombinableLoops
        droplet_results.each do |r|
          log_timing("#{r[:label]} upload timing", r[:upload_timing])
        end

        droplet_results.each do |r|
          log_timing("#{r[:label]} download timing", download_droplet(r[:guid], resource_dir))
        end
        # rubocop:enable Style/CombinableLoops
      ensure
        FileUtils.remove_dir(resource_dir, true) if resource_dir
        FileUtils.remove_dir(zip_output_dir, true) if zip_output_dir

        safe_delete(package_blobstore_client, package_guid)
        Array(big_droplet_guids).each { |g| safe_delete(droplet_blobstore_client, g) }
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
        Tempfile.create('package-download-benchmark', tmp_dir) do |tempfile|
          ::Benchmark.realtime do
            package_blobstore_client.download_from_blobstore(package_guid, tempfile.path)
          end
        end
      end

      def download_buildpacks(tmp_dir)
        Tempfile.create('buildpack-download-benchmark', tmp_dir) do |tempfile|
          bytes_read = 0
          timing = ::Benchmark.realtime do
            bytes_read = Buildpack.map do |buildpack|
              buildpack_blobstore_client.download_from_blobstore(buildpack.key, tempfile.path)
              File.stat(tempfile.path).size
            end.sum
          end
          [bytes_read, timing]
        end
      end

      def upload_droplet(droplet_path)
        copy_to_blobstore(droplet_path, droplet_blobstore_client)
      end

      def download_droplet(droplet_guid, tmp_dir)
        Tempfile.create('droplet-download-benchmark', tmp_dir) do |tempfile|
          ::Benchmark.realtime do
            droplet_blobstore_client.download_from_blobstore(droplet_guid, tempfile.path)
          end
        end
      end

      private

      def log_timing(label, seconds)
        puts("#{label}: #{(seconds * 1000).round(3)}ms")
      end

      def safe_delete(client, guid)
        return if guid.nil?

        client.delete(guid)
      rescue StandardError => e
        # don't fail the benchmark run if cleanup fails
        warn("cleanup failed for guid=#{guid}: #{e.class}: #{e.message}")
      end

      def write_file_of_size(path, bytes)
        File.open(path, 'wb') do |f|
          remaining = bytes
          while remaining > 0
            to_write = [CHUNK_1MB.bytesize, remaining].min
            f.write(CHUNK_1MB, to_write)
            remaining -= to_write
          end
        end
      end

      def generate_resources
        dir = Dir.mktmpdir

        100.times do |i|
          File.write(File.join(dir, i.to_s), 'foo' * (65_536 + i))
        end

        dir
      end

      def zip_resources(resource_dir, output_dir)
        zip_file = File.join(output_dir, 'zipped_package')
        Zip::File.open(zip_file, create: true) do |zipfile|
          Find.find(resource_dir).
            select { |f| File.file?(f) }.
            each { |file| zipfile.add(File.basename(file), file) }
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
