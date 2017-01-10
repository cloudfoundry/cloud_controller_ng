class UploadHandler
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def uploaded_filename(params, resource_name)
    params["#{resource_name}_name"]
  end

  def uploaded_file(params, resource_name)
    if (nginx_file = nginx_uploaded_file(params, resource_name))
      nginx_file
    else
      rack_temporary_file(params, resource_name)
    end
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
end
