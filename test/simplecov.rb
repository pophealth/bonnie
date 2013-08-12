require 'simplecov'
SimpleCov.command_name 'Unit Tests'
SimpleCov.start do
  add_filter "test/"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Models", "app/models"
  add_group "Measures", "lib/measures"
  add_group "Extensions", "lib/ext"
  add_group "Concepts", "lib/concepts"
end

class SimpleCov::Formatter::QualityFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    File.open("coverage/covered_percent", "w") do |f|
      f.puts result.source_files.covered_percent.to_f
    end
  end
end

SimpleCov.formatter = SimpleCov::Formatter::QualityFormatter
