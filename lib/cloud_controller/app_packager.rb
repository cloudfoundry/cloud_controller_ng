require 'find'
require 'open3'
require 'shellwords'
require 'zip'
require 'zip/filesystem'

class AppPackager
  DIRECTORY_DELETE_BATCH_SIZE = 100

  attr_reader :path

  def initialize(zip_path)
    @path = zip_path
  end

  def unzip(destination_dir)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Destination does not exist') unless File.directory?(destination_dir)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Symlink(s) point outside of root folder') if any_outside_symlinks?(destination_dir)

    output, error, status = Open3.capture3(
      %(unzip -qq -n #{Shellwords.escape(@path)} -d #{Shellwords.escape(destination_dir)})
    )

    unless status.success?
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
        "Unzipping had errors\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
    end
  end

  def append_dir_contents(additional_contents_dir)
    unless empty_directory?(additional_contents_dir)
      stdout, error, status = Open3.capture3(
        %(zip -q -r --symlinks #{Shellwords.escape(@path)} .),
        chdir: additional_contents_dir,
      )

      unless status.success?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
          "Could not zip the package\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\"")
      end
    end
  end

  def fix_subdir_permissions
    remove_dirs_from_zip(@path, get_dirs_from_zip(@path))
  rescue Zip::Error
    invalid_zip!
  end

  def size
    Zip::File.open(@path) do |in_zip|
      in_zip.reduce(0) { |memo, entry| memo + entry.size }
    end
  rescue Zip::Error
    invalid_zip!
  end

  private

  def get_dirs_from_zip(zip_path)
    Zip::File.open(zip_path) do |in_zip|
      in_zip.select(&:directory?)
    end
  end

  def remove_dirs_from_zip(zip_path, dirs_from_zip)
    dirs_from_zip.each_slice(DIRECTORY_DELETE_BATCH_SIZE) do |directory_slice|
      remove_dir(zip_path, directory_slice)
    end
  end

  def remove_dir(zip_path, directories)
    directory_arg_list    = directories.map { |dir| Shellwords.escape(dir) }.join(' ')
    stdout, error, status = Open3.capture3(
      %(zip -d #{Shellwords.escape(zip_path)}) + ' ' + directory_arg_list
    )

    unless status.success?
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
        "Could not remove the directories\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\"")
    end
  end

  def any_outside_symlinks?(destination_dir)
    Zip::File.open(@path) do |in_zip|
      in_zip.any? do |entry|
        symlink?(entry) && !safe_path?(in_zip.file.read(entry.name), destination_dir)
      end
    end
  rescue Zip::Error
    invalid_zip!
  end

  def symlink?(entry)
    entry.ftype == :symlink
  end

  def safe_path?(path, destination_dir)
    VCAP::CloudController::FilePathChecker.safe_path?(path, destination_dir)
  end

  def empty_directory?(dir)
    (Dir.entries(dir) - %w(.. .)).empty?
  end

  def invalid_zip!
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Invalid zip archive.')
  end
end
