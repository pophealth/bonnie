source 'https://rubygems.org'

gem 'hqmf2js', :git => 'https://github.com/pophealth/hqmf2js.git', :branch => 'develop'
#gem 'hqmf2js', path: '../hqmf2js'
gem 'hquery-patient-api', :git => 'https://github.com/pophealth/patientapi.git', :branch => 'develop'
#gem 'hquery-patient-api', :path => '../patientapi'
gem 'health-data-standards', :git => 'https://github.com/projectcypress/health-data-standards.git', :branch => 'develop'
#gem 'health-data-standards', :path => '../health-data-standards'
gem 'test-patient-generator', :git => 'https://github.com/pophealth/test-patient-generator.git', :branch => 'develop'
#gem 'test-patient-generator', :path => '../test-patient-generator'
gem 'quality-measure-engine', :git => 'http://github.com/pophealth/quality-measure-engine.git', :branch => 'develop'
#gem 'quality-measure-engine', :path => '../quality-measure-engine'

gem 'rails', '3.2.11'
gem 'jquery-rails', '2.1.4'
gem 'jquery-ui-rails'

gem 'devise'
gem 'foreman'
gem 'cancan'
gem 'factory_girl'
gem 'text'
gem 'spreadsheet', '0.8.3'
gem 'roo', '1.10.3'

gem "mongoid"

gem 'simple_form'
gem 'coderay'   # for javascript syntax highlighting

gem 'pry'
gem 'pry-nav'
gem 'pry-rescue'

group :test, :develop do
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'cover_me'
  gem 'minitest'
end

group :production do
  gem 'libv8', '~> 3.11.8.3'
  gem 'therubyracer', '~> 0.11.0beta5', :platforms => [:ruby] # 10.8 mountain lion compatibility
  gem 'therubyrhino', :platforms => [:jruby] # 10.8 mountain lion compatibility
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
end
