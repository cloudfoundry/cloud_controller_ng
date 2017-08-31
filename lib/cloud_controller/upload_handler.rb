class UploadHandler
  attr_reader :config

  class MissingFilePathError < StandardError
  end
  class InvalidFilePathError < StandardError
  end

  def initialize(config)
    @config = config
  end

  def uploaded_filename(params, resource_name)
    params["#{resource_name}_name"]
  end

  def uploaded_file(params, resource_name)
    if HashUtils.dig(params, '<ngx_upload_module_dummy>')
      raise MissingFilePathError.new('File field missing path information')
    end

    file_path = nginx_uploaded_file(params, resource_name) || rack_temporary_file(params, resource_name)
    return unless file_path

    absolute_path = File.expand_path(file_path, tmpdir)
    unless VCAP::CloudController::FilePathChecker.safe_path?(file_path, tmpdir)
      raise InvalidFilePathError.new('Invalid file path')
    end

    absolute_path
  end

  private

  def nginx_uploaded_file(params, resource_name)
    HashUtils.dig(params, "#{resource_name}_path")
  end

  def rack_temporary_file(params, resource_name)
    resource_params = params[resource_name]
    return unless resource_params.is_a?(Hash)

    tempfile = resource_params[:tempfile] || resource_params['tempfile']
    tempfile.respond_to?(:path) ? tempfile.path : tempfile
  end

  def tmpdir
    config.get(:directories, :tmpdir)
  end
end
