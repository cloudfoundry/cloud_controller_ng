def test
  connection = Fog::Google::DNS.new

  puts "Get the Project limits..."
  puts "-------------------------"
  connection.projects.get(Fog::DNS[:google].project)
end
