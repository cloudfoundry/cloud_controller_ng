module BitsService::Errors
  class Error < StandardError; end

  class FileDoesNotExist < Error; end
  class UnexpectedResponseCode < Error; end
end
