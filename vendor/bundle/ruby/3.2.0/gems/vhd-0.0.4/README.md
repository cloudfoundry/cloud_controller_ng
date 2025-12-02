# vhd-ruby

## About

FFI extension that wraps libvhd in order to create and modify VHD images in Ruby

## Usage

### Create a dynamic VHD

```ruby
Vhd::Library.create_dynamic_disk('some_name.vhd', some_size_in_gb)
```

### Create a fixed VHD

```ruby
Vhd::Library.create_fixed_disk('some_name.vhd', some_size_in_gb)
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
