RSpec.shared_examples_for 'a blobstore client' do
  let!(:tmpfile) do
    Tempfile.open('') do |tmpfile|
      tmpfile.write('file content')
      tmpfile
    end
  end
  let(:key) { 'blobstore-client-shared-key' }
  let(:dest_path) { File.join(Dir.mktmpdir, SecureRandom.uuid) }

  after do
    tmpfile.unlink
    File.delete(dest_path) if File.exist?(dest_path)
  end

  it 'returns true if a key exists' do
    expect(subject.exists?('some-key')).to be_in([true, false])
  end

  it 'downloads from the blobstore' do
    expect do
      subject.download_from_blobstore(key, dest_path, mode: 600)
    end.not_to raise_error
  end

  it 'copies directory contents recursively to the blobstore' do
    Dir.mktmpdir do |dir|
      expect do
        subject.cp_r_to_blobstore(dir)
      end.not_to raise_error
    end
  end

  it 'copies a file to the blobstore' do
    expect do
      subject.cp_to_blobstore(tmpfile.path, 'destination_key')
    end.not_to raise_error
  end

  it 'copies a file to a different key' do
    expect do
      subject.cp_file_between_keys(key, 'destination_key')
    end.not_to raise_error
  end

  it 'deletes all the files from the blobstore' do
    expect do
      page_size = 1
      subject.delete_all(page_size)
    end.not_to raise_error
  end

  it 'deletes all the files in a path from the blobstore' do
    expect do
      subject.delete_all_in_path('some-path')
    end.not_to raise_error
  end

  it 'deletes the file by key in the blobstore' do
    expect do
      subject.delete('source-key')
    end.not_to raise_error
  end

  it 'deletes the blob' do
    expect do
      subject.delete_blob(deletable_blob)
    end.not_to raise_error
  end

  it 'returns a blob object for a file by key' do
    expect(subject.blob(key)).to be_a(CloudController::Blobstore::Blob)
  end

  it 'returns all the files for a given directory prefix' do
    expect do
      subject.files_for('aa')
    end.not_to raise_error
  end

  describe '#ensure_bucket_exists' do
    it 'creates a bucket if it doesnt exist' do
      expect do
        subject.ensure_bucket_exists
      end.not_to raise_error
    end
  end
end
