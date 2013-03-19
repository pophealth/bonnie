module MeasuresHelper

  def include_js_libs(libs)
    library_functions = Measures::Calculator.library_functions
    js = ""
    libs.each do |function|
      js << "#{function}_js = function () { #{library_functions[function]} }\n"
      js << "#{function}_js();\n"
    end
    js << library_functions['hqmf_utils'] + "\n"
  end

  # create a javascript object for the debug view
  def include_js_debug(id, patient_ids, population=0)

    population = population.to_i
    measure = Measure.find(id)
    measure_js = Measures::Calculator.execution_logic(measure, population, true)

    patient_json = Record.find(patient_ids).to_json

    @js = "execute_measure = function(patient) {\n #{measure_js} \n}\n"
    @js << "emitted = []; emit = function(id, value) { emitted.push(value); } \n"
    @js << "ObjectId = function(id, value) { return 1; } \n"

    @js << "// #########################\n"
    @js << "// ######### PATIENT #######\n"
    @js << "// #########################\n\n"

    @js << "var patient = #{patient_json};\n"
    @js << "var effective_date = #{Measure::DEFAULT_EFFECTIVE_DATE};\n"
    @js << "var enable_logging = #{APP_CONFIG['enable_logging']};\n"
    @js << "var enable_rationale = #{APP_CONFIG['enable_rationale']};\n"

    return @js
  end

  def dc_category_style(category)
    case category
    when 'diagnosis_condition_problem'
      'diagnosis'
    when 'laboratory_test'
      'laboratory'
    when 'individual_characteristic'
      'patient'
    else
      category
    end
  end

  def data_criteria_by_category(data_criteria)
    by_category = {}
    data_criteria.each do |key, criteria|
      by_category[criteria["type"]] ||= []
      # need to store the ID since we are putting the criteria into a list
      criteria['criteria_id'] = key
      by_category[criteria["type"]] << criteria
    end if data_criteria
    by_category.each {|category, values| values.sort! {|left,right| left['title'] <=> right['title']}}
    by_category
  end

end
