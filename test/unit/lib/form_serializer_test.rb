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
  
  test "handles nested form" do
    # this is what the rails POST form params look like
    have = {
        "oid"=>"oid",
        "description"=>"description",
        "code_sets"=>{
            "0"=>{
                "code_set"=>"ICD-9-CM",
                "category"=>"category",
                "concept"=>"concept",
                "codes"=>{
                    "0"=>"code0", "1"=>"code1"
                }
            },
            "1"=>{
                "code_set"=>"SNOWMED",
                "category"=>"category",
                "concept"=>"concept",
                "codes"=>{
                    "0"=>"code0", "1"=>"code1"
                }
            }
        }
    }
    
    # this is a hash that we can turn into a mongoid doc
    want = {
        oid: "oid",
        description: "description",
        code_sets: [
            {
                code_set: "ICD-9-CM",
                category: "category",
                concept: "concept",
                codes: [ "code0", "code1" ]
            },
            {
                code_set: "SNOWMED",
                category: "category",
                concept: "concept",
                codes: [ "code0", "code1" ]
            }
        ]
    }
    
    got = @form_serializer.serialize_params(have)
    assert got == want
  end
  
  test "handles arbitrarily nested form" do
    # this is not what we'd likely get in the rails form
    # but stress testing the method to see if it can handle really ugly nesting
    have = {
        "description"=>"description",
        "fruits" => [ 'apple', 'banana', 'orange' ],
        "jagged" => [ 'string', 'another', ['jagged', 'elements'], {hash: "nasty"} ],
        "code_sets"=>{
            "0"=>{
                "concept"=>"concept",
                "codes"=>{
                    "0"=>"code0", "1"=>"code1", "2"=>"something2"
                }
            },
            "1"=>{
                "concept"=>"concept",
                "codes"=>{
                    "0"=>"code0", "1"=>"code1"
                },
                "users" => {
                    "0" => {
                      "name" => "joe",
                      "likes" => ["walks in the park", "dogs"]
                    }
                }
            }
        }
    }

    want = {
        description: "description",
        fruits: [ 'apple', 'banana', 'orange'],
        jagged: [ 'string', 'another', ['jagged', 'elements'], {hash: 'nasty'} ],
        code_sets: [
            {
                concept: "concept",
                codes: [ "code0", "code1", "something2"]
            },
            {
                concept: "concept",
                codes: [ "code0", "code1" ],
                users: [ {
                            name: "joe",
                            likes: ["walks in the park", "dogs"]
                         }]
            }
        ]
    }

    got = @form_serializer.serialize_params(have)
    assert got == want
  end
  
  test 'handles hashes in array' do
    # our code textboxes probably wouldn't have a nested form in them
    have = {
      "employees" => {
        "0" => {
          'name' => 'bob', 
          'jobs' => ['ceo', 'janitor', {never: 'chef'} ]
        }
      }
    }
    
    want = {
      employees: [
        name: 'bob',
        jobs: ['ceo', 'janitor', {never: 'chef'} ]
      ]
    }

    got = @form_serializer.serialize_params(have)
    assert got == want
  end
  
end