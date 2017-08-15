require 'spec_helper'
require 'vcap/digester'

RSpec.describe 'Stable API warning system', api_version_check: true do
  API_FOLDER_CHECKSUM = '5fe09b6aaca2f5e712654adb2ab8ef6299f50a1a'.freeze

  it 'tells the developer if the API specs change' do
    api_folder = File.expand_path('..', __FILE__)
    filenames = Dir.glob("#{api_folder}/**/*").reject { |filename| File.directory?(filename) || filename == __FILE__ || filename.include?('v3') }.sort

    all_file_checksum = filenames.each_with_object('') do |filename, memo|
      memo << Digester.new.digest_path(filename)
    end

    new_checksum = Digester.new.digest(all_file_checksum)

    expect(new_checksum).to eql(API_FOLDER_CHECKSUM),
      <<~END
        You are about to make a breaking change in API!

        Do you really want to do it? Then update the checksum (see below) & CC version.

        expected:
            #{API_FOLDER_CHECKSUM}
        got:
            #{new_checksum}
    END
  end
end
