require "zipruby"
require "find"

class SafeZipper
  def self.unzip(zip_path, zip_destination)
    new(zip_path, zip_destination).unzip!
  end

  def self.zip(root_path, zip_output)
    new(root_path, zip_output).zip!
  end

  def initialize(zip_path, zip_destination)
    @zip_path = File.expand_path(zip_path)
    @zip_destination = File.expand_path(zip_destination)
  end

  def unzip!
    raise VCAP::Errors::AppBitsUploadInvalid, "Destination does not exist" unless File.directory?(@zip_destination)
    raise VCAP::Errors::AppBitsUploadInvalid, "Relative path(s) outside of root folder" if any_outside_relative_paths?

    unzip

    raise VCAP::Errors::AppBitsUploadInvalid, "Symlink(s) point outside of root folder" if any_outside_symlinks?

    size
  end

  def zip!
    raise VCAP::Errors::AppPackageInvalid, "Path does not exist" unless File.exists?(@zip_path)
    raise VCAP::Errors::AppPackageInvalid, "Path does not exist" unless File.exists?(File.dirname(@zip_destination))

    FileUtils.cd(@zip_path) { zip }
  end

  private

  def unzip
    @unzip ||= `unzip -qq -: -d #{@zip_destination} #{@zip_path}`
  end

  def zip
    @zip ||= begin
      output = `zip -r --symlinks #{@zip_destination} .`
      raise VCAP::Errors::AppPackageInvalid, "Could not zip the package" unless $?.success?
      output
    end
  end

  def zip_info
    @zip_info ||= begin
      output = `unzip -l #{@zip_path}`
      raise VCAP::Errors::AppBitsUploadInvalid, "Unzipping had errors" unless $?.success?
      output
    end
  end

  def size
    @size ||= zip_info.split("\n").last.match(/^\s+(\d+)/)[1].to_i
  end

  def any_outside_relative_paths?
    zip_info.split("\n")[3..-3].find do |line|
      is_outside?(line.match(/([^\s]+)$/)[1])
    end
  end

  def any_outside_symlinks?
    Find.find(@zip_destination).find do |item|
      File.symlink?(item) && is_outside?(File.readlink(item))
    end
  end

  def is_outside?(path)
    !File.expand_path(path, @zip_destination).start_with?("#{@zip_destination}/")
  end
end