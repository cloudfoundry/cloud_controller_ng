module VCAP::CloudController
  module Buildpacks
    class StackNameExtractor
      ONE_MEGABYTE = 1024 * 1024

      def self.extract_from_file(bits_file_path)
        bits_file_path = bits_file_path.path if bits_file_path.respond_to?(:path)
        Zip::File.open(bits_file_path) do |zip_file|
          zip_file.each do |entry|
            if entry.name == 'manifest.yml'
              raise CloudController::Errors::BuildpackError.new('buildpack manifest is too large') if entry.size > ONE_MEGABYTE
              return YAML.safe_load(entry.get_input_stream.read).dig('stack')
            end
          end
        end
        nil
      rescue Psych::Exception
        raise CloudController::Errors::BuildpackError.new('buildpack manifest is not valid')
      rescue Zip::Error
        raise CloudController::Errors::BuildpackError.new('buildpack zipfile is not valid')
      end
    end
  end
end
