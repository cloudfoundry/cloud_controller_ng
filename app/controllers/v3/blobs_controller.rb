class BlobsController < ApplicationController

  def show
    client = CloudController::DependencyLocator.instance.credhub_client

    response.headers["ETag"] = 'version1'
    response.headers["Last-Modified"] = 'Sat, 1 Apr 2023 00:00:00 GMT'
    send_data(decode_file(client.get_chunked_credential_by_name(hashed_params[:key])), filename: 'file')
  end

  private

  def decode_file(data)
    Base64.strict_decode64(data).force_encoding('BINARY')
  end

  def enforce_read_scope?
    false
  end

  def enforce_authentication?
    false
  end
end
