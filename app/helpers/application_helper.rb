module ApplicationHelper

  def measure_js(measure, population)
    Measures::Calculator.execution_logic(measure, population, true)
  end

end
