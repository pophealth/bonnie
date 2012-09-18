require 'factory_girl'

FactoryGirl.define do

  factory :code_set do |f|
    f.category { ValueSet::Categories.sample }
    f.oid "2.16.840.1.113883.3.464.0002.1138"
    f.code_set "RxNorm"
    f.concept "Encounters ALL inpatient and ambulatory"
    f.sequence(:codes) { |n| ["99201", "99202", "99203", "99204", "1234#{n}"] }
  end

  factory :unrelated_code_set, :parent => :code_set do |f|
    f.codes ["abc", "123"]
  end

  factory :value_set do |f|
    f.category { ValueSet::Categories.sample }
    f.oid "1.2.3.4"
    f.concept "Encounters ALL inpatient and ambulatory"
  end

  factory :concept do |f|
    f.sequence(:name) { |n| "concept#{n}"}
    f.sequence(:oids) { |n| ["1.2.0.#{n}", "2.3.0.#{n}"]}
  end

  factory :measure do |m| 
    m.sequence(:endorser) { |n| "NQF" }
    m.sequence(:measure_id) { |n| "00#{n}" }
    m.sequence(:title)  { |n| "Measure #{n}" }
    m.sequence(:description)  { |n| "This is the description for measure #{n}" }
    m.published false
    m.user User.first
  end
  
  factory :published_measure, :parent => :measure do |m|
    m.published true
    m.version 1
    m.publish_date (1..500).to_a.sample.days.ago
  end
  
  # TODO: not a complete Record with all attributes, problems with custom attributes
  # minimal Record factory for testing where fixtures from disk might be weird
  factory :record do |r|
    r.effective_time Random.rand(9999999999)
    r.sequence(:first) { |n| "First#{n}" }
    r.sequence(:last) { |n| "Last#{n}" }
    r.birthdate Random.rand(999999999) * -1
    r.gender ["M", "F"].sample
    r.medical_record_number "4f71cb938e27b4a09300007b"
    r.race ({
      :code => "", 
      :code_set => "CDC-RE"
    })    
    r.ethnicity ({
      :code => "",
      :code_set => "CDC-RE"
    })
    r.languages [ "en-US" ]
    # r.sequence(:measures) {|s|
    #   "0001" => { 
    #     "encounter_office_outpatient_consult_encounter" => [ 
    #       Array.new(4).fill { Random.rand(1000000000..1999999999) } 
    #     ]
    #   }
    # }
    r.allergies([
      {
        :codes => [],
        :value => [],
        :_type => "Allergy",
        :time => nil,
        :start_time => nil,
        :reaction => nil,
        :severity => nil
      }
    ])
    # "conditions" : [ 
    #   { "codes" : { "SNOMED-CT" : [ 
    #         "49436004" ],
    #       "ICD-9-CM" : [ 
    #         "427.31" ],
    #       "ICD-10-CM" : [ 
    #         "I48.0" ] },
    #     "value" : {},
    #     "_type" : "Condition",
    #     "time" : null,
    #     "start_time" : 1280721600,
    #     "status" : "active",
    #     "description" : "Atrial Fibrillation",
    #     "causeOfDeath" : false,
    #     "type" : "Condition" },
    # "encounters" : [ 
    #   { "codes" : { "CPT" : [ 
    #         "99213" ],
    #       "ICD-9-CM" : [ 
    #         "V70.0" ] },
    #     "value" : {},
    #     "_type" : "Encounter",
    #     "time" : 1289883600,
    #     "description" : "Encounter Outpatient",
    #     "admitType" : null }, 
    # "immunizations" : [ 
    #   { "codes" : { "RxNorm" : [ 
    #         "857942" ] },
    #     "value" : {},
    #     "_type" : "Immunization",
    #     "time" : 1289883600,
    #     "description" : "Influenza Vaccine",
    #     "refusalInd" : false }, 
    # "medications" : [ 
    #   { "codes" : { "RxNorm" : [ 
    #         "314076" ] },
    #     "value" : {},
    #     "_type" : "Medication",
    #     "time" : null,
    #     "start_time" : 1276401600,
    #     "end_time" : null,
    #     "description" : "ACE inhibitor or ARB",
    #     "freeTextSig" : "ACE inhibitor or ARB",
    #     "route" : null,
    #     "dose" : null,
    #     "site" : null,
    #     "productForm" : null,
    #     "deliveryMethod" : null,
    #     "typeOfMedication" : null,
    #     "indication" : null,
    #     "vehicle" : null }, 
    # "procedures" : [ 
    #   { "codes" : { "SNOMED-CT" : [ 
    #         "70822001" ] },
    #     "value" : {},
    #     "_type" : "Procedure",
    #     "time" : 1276401600,
    #     "description" : "Ejection Fraction",
    #     "site" : null } ],
    # "results" : [ 
    #   { "codes" : { "LOINC" : [ 
    #         "14646-4" ],
    #       "CPT" : [ 
    #         "83701" ],
    #       "SNOMED-CT" : [ 
    #         "28036006" ] },
    #     "value" : { "scalar" : "48.0",
    #       "units" : null },
    #     "_type" : "LabResult",
    #     "time" : 1275451200,
    #     "status" : "completed",
    #     "description" : "High Density Lipoprotein (HDL)" }, 
    # "vital_signs" : [ 
    #   { "codes" : { "SNOMED-CT" : [ 
    #         "271649006" ] },
    #     "value" : { "scalar" : "136.0",
    #       "units" : "mm[Hg]" },
    #     "_type" : "LabResult",
    #     "time" : 1289883600,
    #     "status" : "completed",
    #     "description" : "Systolic Blood Pressure" }, 
  end

  # ==========
  # = USERS =
  # ==========

  factory :user do |u| 
    u.sequence(:email) { |n| "testuser#{n}@test.com"} 
    u.password 'password' 
    u.password_confirmation 'password'
    u.first_name 'first'
    u.last_name 'last'
    u.sequence(:username) { |n| "testuser#{n}"}
    u.admin false
    u.approved true
    u.agree_license true
  end

  factory :admin, :parent => :user do |u|
    u.admin true
  end

  factory :unapproved_user, :parent => :user do |u|
    u.approved false
  end  
end
