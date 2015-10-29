# Create an app using V3 of the Cloud Controller API

1. Find the GUID of your space:

  `cf space [your-space] --guid`

1. Create an empty app ([docs](http://apidocs.cloudfoundry.org/release-candidate/apps_(experimental)/create_an_app.html)):

  `cf curl /v3/apps -X POST -d '{"name":"app-name","relationships": {"space": {"guid": "[your-space-guid]"} } }'`

  Note: The output of this command includes your new app's GUID

  App now also accepts `lifecycle` settings. To create the app with a specific `buildpack` or `stack` do the following:

  ```
  cf curl /v3/apps -X POST -d '{"name":"app-name",
                                "relationships": {"space": {"guid": "[your-space-guid]"} },
                                "lifecycle": { "type": "buildpack", "data": { "stack": "cflinuxfs2", "buildpack": "ruby_buildpack"}}'`
  ```

1. Create an empty package for the app ([docs](http://apidocs.cloudfoundry.org/release-candidate/packages_(experimental)/create_a_package.html)):

  `cf curl /v3/apps/[your-app-guid]/packages -X POST -d '{"type":"bits"}'`

  Note: The output of this command includes your new package's GUID  
  Note: Other package types are also supported. See documentation for Create a Package.

1. Create a ZIP file of your application:

  `zip -r my-app.zip *`

  Note: The zip file should not have a folder as the top-level item (e.g. create the zip file from within your app’s directory)

1. Upload your bits to your new package ([docs](http://apidocs.cloudfoundry.org/release-candidate/packages_(experimental)/upload_bits_for_a_package_of_type_bits.html)):

  ``curl -s https://api.example.com/v3/packages/[your-package-guid]/upload -F bits=@"my-app.zip" -H "Authorization: `cf oauth-token | grep bearer`"``

1. Stage your package and create a droplet ([docs](http://apidocs.cloudfoundry.org/release-candidate/packages_(experimental)/stage_a_package.html)):

  `cf curl /v3/packages/[your-package-guid]/droplets -X POST -d '{}'`

  Note: The output of this command includes your new droplet's GUID

1. Assign your droplet to your app ([docs](http://apidocs.cloudfoundry.org/release-candidate/apps_(experimental)/assigning_a_droplet_as_a_an_apps_current_droplet.html)):

  `cf curl /v3/apps/[your-app-guid]/current_droplet -X PUT -d '{"droplet_guid": "[your-droplet-guid]"}'`

1. Create a route:

  `CF_TRACE=true cf create-route [space-name] [domain-name] -n [host-name]`

  Note: The CF_TRACE output includes your new route's GUID under metadata->guid of the last response

1. Map the route to your app ([docs](http://apidocs.cloudfoundry.org/release-candidate/app_routes_(experimental)/map_a_route.html)):

  `cf curl /v3/apps/[your-app-guid]/routes -X PUT -d '{"route_guid": "[your-route-guid]"}'`

1. Start your app ([docs](http://apidocs.cloudfoundry.org/release-candidate/apps_(experimental)/starting_an_app.html)):

  `cf curl /v3/apps/[your-app-guid]/start -X PUT`

1. Visit your app at the new route to confirm that it is up
