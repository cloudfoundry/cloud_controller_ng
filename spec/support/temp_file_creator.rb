module TempFileCreator
  def temp_file_with_content(content = Sham.guid)
    file = Tempfile.new("a_file")
    file.write(content)
    file.flush
    @created_temp_files ||= []
    @created_temp_files << file
    file
  end

  def delete_created_temp_files
    @created_temp_files && @created_temp_files.each { |file| file.unlink }
  end
end
