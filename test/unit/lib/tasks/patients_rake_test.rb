require 'test_helper'

class PatientsRakeTest < ActiveSupport::TestCase  
  @@rake = nil
  
  setup do    
    dump_database
    
    unless @@rake
      @@rake = Rake.application
      Rake.application = @@rake
      Rake.application.rake_require "../../lib/tasks/patients"
      Rake::Task.define_task(:environment)
    end
    Rake.application.tasks.each {|t| t.instance_eval{@already_invoked = false}}
  end
  
  test "rake task loads 225 records from patients json file" do
    starting_doc_count = Record.count
    @@rake['patients:load'].invoke
    assert_equal Record.count, 225
  end
end