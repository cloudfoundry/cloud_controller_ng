require 'spec_helper'
require 'digest/sha1'

describe 'Stable API warning system', api_version_check: true do
  API_FOLDER_CHECKSUM = '9260f069b9792f67455297a5318e3b1619f3f395'

  it 'double-checks the version' do
    expect(VCAP::CloudController::Constants::API_VERSION).to eq('2.33.0')
  end

  it 'tells the developer if the API specs change' do
    api_folder = File.expand_path('..', __FILE__)
    filenames = Dir.glob("#{api_folder}/**/*").reject { |filename| File.directory?(filename) || filename == __FILE__ || filename.include?('v3') }.sort

    all_file_checksum = filenames.each_with_object('') do |filename, memo|
      memo << Digest::SHA1.file(filename).hexdigest
    end

    new_checksum = Digest::SHA1.hexdigest(all_file_checksum)

    expect(new_checksum).to eql(API_FOLDER_CHECKSUM),
      <<-END
You are about to make a breaking change in API!

Do you really want to do it? Then update the checksum (see below) & CC version.

expected:
    #{API_FOLDER_CHECKSUM}
got:
    #{new_checksum}
    END
  end
end
