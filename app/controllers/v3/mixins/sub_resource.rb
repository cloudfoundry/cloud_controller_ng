module SubResource
  private

  def app_not_found!
    resource_not_found!(:app)
  end

  def base_url(resource:)
    if app_nested?
      "/v3/apps/#{params[:app_guid]}/#{resource}"
    elsif package_nested?
      "/v3/packages/#{params[:package_guid]}/#{resource}"
    else
      "/v3/#{resource}"
    end
  end

  def app_nested?
    params[:app_guid].present?
  end

  def package_nested?
    params[:package_guid].present?
  end

  def subresource_query_params
    if app_nested?
      query_params.merge(app_guid: params[:app_guid])
    elsif package_nested?
      query_params.merge(package_guid: params[:package_guid])
    else
      query_params
    end
  end
end
