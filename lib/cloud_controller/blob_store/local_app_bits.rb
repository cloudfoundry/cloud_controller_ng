require "cloud_controller/safe_zipper"
require "ext/file"

class LocalAppBits
  PACKAGE_NAME = "package.zip".freeze

  def self.from_compressed_bits(compressed_bits_path, &block)
    Dir.mktmpdir("uncompressed", Settings.tmp_dir) do |unzip_path|
      storage_size = 0
      if compressed_bits_path && File.exists?(compressed_bits_path)
        storage_size = SafeZipper.unzip(compressed_bits_path, unzip_path)
      end
      block.yield new(unzip_path, storage_size)
    end
  end

  attr_reader :root_path, :storage_size

  def initialize(root_path, storage_size)
    @root_path = root_path
    @storage_size = storage_size
  end

  def create_package
    destination = File.join(root_path, PACKAGE_NAME)
    SafeZipper.zip(root_path, destination)
    File.new(destination)
  end
end