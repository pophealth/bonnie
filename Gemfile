source 'https://rubygems.org'

gem 'hqmf-parser', :git => 'https://github.com/pophealth/hqmf-parser.git', :branch => 'develop'
#gem 'hqmf-parser', path: '../hqmf-parser'
gem 'hqmf2js', :git => 'https://github.com/pophealth/hqmf2js.git', :branch => 'develop'
#gem 'hqmf2js', path: '../hqmf2js'
gem 'hquery-patient-api', :git => 'https://github.com/pophealth/patientapi.git', :branch => 'develop'
#gem 'hquery-patient-api', :path => '../patientapi'
gem 'health-data-standards', :git => 'https://github.com/projectcypress/health-data-standards.git', :branch => 'develop'
gem 'test-patient-generator', :git => 'https://github.com/pophealth/test-patient-generator.git', :branch => 'develop'
#gem 'test-patient-generator', :path => '../test-patient-generator'
gem 'quality-measure-engine', :git => 'http://github.com/pophealth/quality-measure-engine.git', :branch => 'develop'
#gem 'quality-measure-engine', :path => '../quality-measure-engine'

gem 'rails', '3.2.2'
gem 'jquery-rails'
gem 'jquery-ui-rails'

gem 'devise'
gem 'foreman'
gem 'cancan'
gem 'factory_girl'

gem "mongo", '1.6.2'
gem "mongoid"
gem "bson"
gem 'bson_ext'

gem 'simple_form'
gem 'coderay'   # for javascript syntax highlighting

gem 'pry'
gem 'pry-nav'

group :test, :develop do
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'cover_me'
  gem 'minitest'
  gem 'mocha', :require => false
  gem 'spork', "~> 0.9.0"
  gem 'rb-inotify' if RUBY_PLATFORM.downcase.include?("linux")
  gem 'rb-fsevent', "~> 0.9.0" if RUBY_PLATFORM.downcase.include?("darwin")
  gem 'guard', "~> 1.0.1"
  gem 'guard-spork', "~> 0.5.2"
  gem 'guard-minitest', "~> 0.5.0"
  gem 'spork-testunit', "~> 0.0.8"
end

group :production do
  gem 'libv8', '~> 3.11.8.3'                                          # 10.8 mountain lion compatibility
  gem 'therubyracer', '~> 0.11.0beta5', :platforms => [:ruby, :jruby] # 10.8 mountain lion compatibility
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
end
