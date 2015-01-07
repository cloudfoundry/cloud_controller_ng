class UploadHandler
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def uploaded_filename(params, resource_name)
    params["#{resource_name}_name"]
  end

  def uploaded_file(params, resource_name)
    if using_nginx?
      nginx_uploaded_file(params, resource_name)
    else
      rack_temporary_file(params, resource_name)
    end
  end

  private

  def using_nginx?
    config[:nginx][:use_nginx]
  end

  def nginx_uploaded_file(params, resource_name)
    params["#{resource_name}_path"]
  end

  def rack_temporary_file(params, resource_name)
    resource_params = params[resource_name]
    return unless resource_params.respond_to?(:[])

    tempfile = resource_params[:tempfile] || resource_params['tempfile']
    tempfile.respond_to?(:path) ? tempfile.path : tempfile
  end
end
