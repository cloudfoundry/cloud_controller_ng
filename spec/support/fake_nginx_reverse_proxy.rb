require 'rack/test'
require 'tmpdir'

class FakeNginxReverseProxy
  def initialize(app)
    @app = app
  end

  def call(env)
    tmpdir = nil
    if multipart?(env)
      form_hash = Rack::Multipart.parse_multipart(env.dup)
      tmpdir = Dir.mktmpdir('ngx.uploads')
      offload_files!(form_hash, tmpdir)
      offload_staging!(form_hash, tmpdir)
      data = Rack::Multipart::Generator.new(form_hash).dump
      raise ArgumentError unless data
      env['rack.input'] = StringIO.new(data)
      env['CONTENT_LENGTH'] = data.size.to_s
      env['CONTENT_TYPE'] = "multipart/form-data; boundary=#{Rack::Utils::Multipart::MULTIPART_BOUNDARY}"
    end
    @app.call(env)
  ensure
    FileUtils.remove_entry_secure(tmpdir) if tmpdir
  end

  private

  def multipart?(env)
    return false unless ['PUT', 'POST'].include?(env['REQUEST_METHOD'])
    env['CONTENT_TYPE'].downcase.start_with?('multipart/form-data; boundary')
  end

  # @param [Hash] form_hash an env hash containing multipart file fields
  # @return [Hash] the same hash, with file fields replaced by names to files in +tmpdir+
  def offload_files!(form_hash, tmpdir)
    file_keys = form_hash.keys.select do |k|
      next unless k.is_a?(String)
      form_hash[k].is_a?(Hash) && form_hash[k][:tempfile]
    end
    file_keys.each do |k|
      replace_form_field(form_hash, k, tmpdir)
    end
    form_hash
  end

  # @param [Hash] form_hash an env hash containing multipart file fields
  # @return [Hash] same hash, with +form_hash[key]+ replaced by name to file in +tmpdir+
  def replace_form_field(form_hash, key, tmpdir)
    v = form_hash.delete(key)
    FileUtils.copy(v[:tempfile].path, tmpdir)
    form_hash.update(
      {
        "#{key}_name" => v[:filename],
        "#{key}_path" => File.join(tmpdir, File.basename(v[:tempfile].path)),
        # keeps the uploaded file to trick the multipart encoder, but
        # obfuscates the form field name so we're not likely gonna use it
        sprintf('%06x', rand(0x1000000)) => Rack::Multipart::UploadedFile.new(v[:tempfile].path),
      }
    )
    v[:tempfile].unlink
    form_hash
  end

  # similar to +offload_files!+, but only replaces upload[droplet] to droplet_path
  def offload_staging!(form_hash, tmpdir)
    if form_hash['upload']
      upload_form = replace_form_field(
        form_hash.delete('upload'),
        'droplet',
        tmpdir
      ).reject { |k, _| k == 'droplet_name' }
      form_hash.update(upload_form)
    end
  end
end
