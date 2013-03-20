module MeasuresHelper

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
