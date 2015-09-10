require 'find'
require 'open3'

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
    raise VCAP::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Destination does not exist') unless File.directory?(@zip_destination)
    raise VCAP::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Relative path(s) outside of root folder') if any_outside_relative_paths?

    unzip

    raise VCAP::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Symlink(s) point outside of root folder') if any_outside_symlinks?

    size
  end

  def zip!
    raise VCAP::Errors::ApiError.new_from_details('AppPackageInvalid', 'Path does not exist') unless File.exist?(@zip_path)
    raise VCAP::Errors::ApiError.new_from_details('AppPackageInvalid', 'Path does not exist') unless File.exist?(File.dirname(@zip_destination))

    zip
  end

  private

  def unzip
    @unzip ||= `unzip -qq -: -d #{@zip_destination} #{@zip_path}`
  end

  def zip
    @zip ||= begin
      output, error, status = Open3.capture3(
        %(zip -q -r --symlinks #{@zip_destination} .),
        chdir: @zip_path
      )

      unless status.success?
        raise VCAP::Errors::ApiError.new_from_details('AppPackageInvalid',
          "Could not zip the package\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
      end

      output
    end
  end

  def zip_info
    @zip_info ||= begin
      output, error, status = Open3.capture3(%(unzip -l #{@zip_path}))

      unless status.success?
        raise VCAP::Errors::ApiError.new_from_details('AppBitsUploadInvalid',
          "Unzipping had errors\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
      end

      output
    end
  end

  def size
    @size ||= zip_info.split("\n").last.match(/^\s*(\d+)/)[1].to_i
  end

  def any_outside_relative_paths?
    zip_info.split("\n")[3..-3].any? do |line|
      match = line.match(/^\s*\d+\s+[\d-]+\s+[\d:]+\s+(.*)$/)
      match && is_outside?(match[1])
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
