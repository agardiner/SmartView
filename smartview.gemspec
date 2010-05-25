require 'rubygems'

GEMSPEC = Gem::Specification.new do |spec|
    spec.name = 'smartview'
    spec.summary = 'A library for communicating with Hyperion SmartView providers'
    spec.description = %{Provides a Ruby library for communicating with Hyperion SmartView providers for the purposes of retrieving metadata and data from Essbase, Planning, and HFM applications.}
    spec.author = 'Adam Gardiner'
    spec.email = 'adam.b.gardiner@gmail.com'
    spec.require_paths = ['lib']
    spec.files = ['README.rdoc', 'COPYING'] + Dir['lib/**/*.rb']
    spec.version = '0.0.3'
    spec.add_dependency 'builder'
    spec.add_dependency 'hpricot'
    spec.add_dependency 'httpclient'
end

