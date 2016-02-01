shared_examples_for 'a blobstore client' do
  let!(:tmpfile) do
    Tempfile.open('') do |tmpfile|
      tmpfile.write('file content')
      tmpfile
    end
  end
  let(:key) { 'blobstore-client-shared-key' }
  let(:dest_path) { Dir::Tmpname.make_tmpname(Dir.mktmpdir, nil) }

  after do
    tmpfile.unlink
    File.delete(dest_path) if File.exist?(dest_path)
  end

  it 'returns true if a key exists' do
    expect(subject.exists?('some-key')).to be_in([true, false])
  end

  it 'downloads from the blobstore' do
    expect {
      subject.download_from_blobstore(key, dest_path, mode: 600)
    }.not_to raise_error
  end

  it 'copies directory contents recursively to the blobstore' do
    Dir.mktmpdir do |dir|
      expect {
        subject.cp_r_to_blobstore(dir)
      }.not_to raise_error
    end
  end

  it 'copies a file to the blobstore' do
    expect {
      retry_count = 2
      subject.cp_to_blobstore(tmpfile.path, 'destination_key', retry_count)
    }.not_to raise_error
  end

  it 'copies a file to a different key' do
    expect {
      subject.cp_file_between_keys(key, 'destination_key')
    }.not_to raise_error
  end

  it 'deletes all the files from the blobstore' do
    expect {
      page_size = 1
      subject.delete_all(page_size)
    }.not_to raise_error
  end

  it 'deletes all the files in a path from the blobstore' do
    expect {
      subject.delete_all_in_path('some-path')
    }.not_to raise_error
  end

  it 'deletes the file by key in the blobstore' do
    expect {
      subject.delete('source-key')
    }.not_to raise_error
  end

  it 'deletes the blob' do
    expect {
      subject.delete_blob(deletable_blob)
    }.not_to raise_error
  end

  it 'returns a blob object for a file by key' do
    expect(subject.blob(key)).to be_a(CloudController::Blobstore::Blob)
  end
end
