require "cloud_controller/safe_zipper"

class LocalAppBits
  PACKAGE_NAME = "package.zip".freeze

  def self.from_zip_of_new_files(zip_path, &block)
    Dir.mktmpdir("unzipped", Settings.tmp_dir) do |unzip_path|
      storage_size = SafeZipper.unzip(zip_path, unzip_path)
      block.yield new(unzip_path, storage_size)
    end
  end

  attr_reader :root_path, :storage_size

  def initialize(unzip_path, storage_size)
    @root_path = unzip_path
    @storage_size = storage_size
  end

  def create_package
    destination = File.join(root_path, PACKAGE_NAME)
    SafeZipper.zip(root_path, destination)
    destination
  end
end