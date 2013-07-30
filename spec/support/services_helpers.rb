module ServicesHelpers
  def fake_app_staging(app)
    app.package_hash = "abc"
    app.droplet_hash = "def"
    app.save
    app.needs_staging?.should be_false
  end
end