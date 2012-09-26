class CodeSetOverlap
  include Mongoid::Document

  field :code_set, type: String
  field :overlap_percentage, type: Float

  def calculate_overlap(code_list_one, code_list_two)
    intersection_size = (code_list_one & code_list_two).size.to_f
    union_size = (code_list_one | code_list_two).size.to_f

    self.overlap_percentage = intersection_size / union_size
  end
end