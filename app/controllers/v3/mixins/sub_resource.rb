module SubResource
  private

  def base_url(resource:)
    if app_nested?
      "/v3/apps/#{hashed_params[:app_guid]}/#{resource}"
    elsif package_nested?
      "/v3/packages/#{hashed_params[:package_guid]}/#{resource}"
    elsif process_nested?
      "/v3/processes/#{hashed_params[:process_guid]}/#{resource}"
    elsif isolation_segment_nested?
      "/v3/isolation_segments/#{hashed_params[:isolation_segment_guid]}/#{resource}"
    else
      "/v3/#{resource}"
    end
  end

  def app_nested?
    hashed_params[:app_guid].present?
  end

  def package_nested?
    hashed_params[:package_guid].present?
  end

  def process_nested?
    hashed_params[:process_guid].present?
  end

  def isolation_segment_nested?
    hashed_params[:isolation_segment_guid].present?
  end

  def subresource_query_params
    if app_nested?
      query_params.merge(app_guid: hashed_params[:app_guid])
    elsif package_nested?
      query_params.merge(package_guid: hashed_params[:package_guid])
    elsif isolation_segment_nested?
      query_params.merge(isolation_segment_guid: hashed_params[:isolation_segment_guid])
    else
      query_params
    end
  end
end
