require 'fog/core'
require 'fileutils'
require 'tempfile'

require 'fog/local/version'

module Fog
  module Local
    extend Provider

    autoload :Storage, 'fog/local/storage'
    service :storage, :Storage
  end
end

Fog::Storage::Local = Fog::Local::Storage # legacy compat
