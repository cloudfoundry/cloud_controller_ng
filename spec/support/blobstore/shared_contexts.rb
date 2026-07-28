RSpec.shared_context 'a remote blobstore' do |download_url: 'http://blobstore.example.com/download'|
  before do
    allow_any_instance_of(CloudController::Blobstore::LocalClient).to receive(:local?).and_return(false)
    allow_any_instance_of(CloudController::Blobstore::LocalBlob).to receive_messages(
      internal_download_url: download_url,
      public_download_url: download_url
    )
  end
end

RSpec.shared_context 'a seeded empty-file resource' do
  before do
    empty_file = Tempfile.new('empty')
    CloudController::DependencyLocator.instance.global_app_bits_cache.cp_to_blobstore(
      empty_file.path, 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
    )
    empty_file.close
  end
end
