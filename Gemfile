source 'https://rubygems.org'

gem 'hqmf2js', '~> 1.2.0'
gem 'hquery-patient-api', '~> 1.0.1'
gem 'health-data-standards', '~> 3.0.2'
gem 'test-patient-generator', '~> 1.2.0'
gem 'quality-measure-engine', '~> 2.3.0'

gem 'rails', '3.2.9'
gem 'jquery-rails'
gem 'jquery-ui-rails'

gem 'devise'
gem 'foreman'
gem 'cancan'
gem 'factory_girl'
gem 'text'
gem 'rubyXL'

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
