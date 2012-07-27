require 'test_helper'

class FormSerializerTest < ActiveSupport::TestCase
  
  setup do
    @form_serializer = FormSerializer.new
  end
  
  test "handles an unnested form" do
    have = { "fire"=>"hot", "ice"=>"cold", "earth"=>"dirty" }
    want = { fire: "hot", ice: "cold", earth: "dirty" }
    got = @form_serializer.serialize_params(have)
    
    assert got == want
  end
  
end