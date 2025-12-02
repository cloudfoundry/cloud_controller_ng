module Fog
  module Local
    class Storage
      class Directory < Fog::Model
        identity  :key

        def destroy
          requires :key

          if ::File.directory?(path)
            Dir.rmdir(path)
            true
          else
            false
          end
        end

        def files
          @files ||= Files.new(directory: self, service: service)
        end

        def public=(new_public)
          new_public
        end

        def public_url
          nil
        end

        def save
          requires :key

          FileUtils.mkpath(path)
          true
        end

        private

        def path
          service.path_to(key)
        end
      end
    end
  end
end
