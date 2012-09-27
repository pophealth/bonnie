require 'factory_girl'

FactoryGirl.define do

  sequence :oid do
    s = ""
    9.times { s << (1..9).to_a.sample(rand(6)+1).join.to_s << "." }
    s.chop
  end

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
    measure
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
    r.effective_time 1293771600000
    r.sequence(:first) { |n| "First#{n}" }
    r.sequence(:last) { |n| "Last#{n}" }
    r.birthdate 915179400
    r.gender "M"
    r.race ({:code => "", :code_set => "CDC-RE"})    
    r.ethnicity ({:code => "", :code_set => "CDC-RE"})
    r.languages [ "en-US" ]
    r.type 'ep'
    r.conditions []
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
