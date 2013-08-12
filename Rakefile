#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Bonnie::Application.load_tasks
ENV['DB_NAME'] = "bonnie-#{Rails.env}"
task "resque:setup" => :environment

Rake::TestTask.new(:test_unit) do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task :test => [:test_unit] do
  system("open coverage/index.html")
end
