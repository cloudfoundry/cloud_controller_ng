module VCAP
  module CloudController
    class FilePathChecker
      def self.safe_path?(child_path, root_path='/root_path')
        expanded_path = File.expand_path(child_path, root_path)

        !!expanded_path.match(/^#{root_path}/)
      end
    end
  end
end
