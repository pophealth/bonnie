class ValueSet
  include Mongoid::Document
  
  field :key, type: String
  field :concept, type: String
  field :oid, type: String
  field :category, type: String
  field :description, type: String
  field :organization, type: String
  field :version, type: String
  
  embeds_many :code_sets, as: :code_settable
  belongs_to :measure
  
  accepts_nested_attributes_for :code_sets
  attr_accessible :key, :concept, :code_sets, :oid, :category, 
    :description, :organization, :version
  
  # diagnosis_condition_problem
  Categories = %w(
    encounter
    procedure
    risk_category_assessment
    communication
    laboratory_test
    physical_exam
    medication
    condition_diagnosis_problem
    diagnosis_condition_problem
    symptom
    individual_characteristic
    device
    care_goal
    diagnostic_study
    substance
    attribute
    intervention
    result
    patient_provider_interaction
    functional_status
    transfer_of_care
  )
  
  validates_format_of :oid, with: /^(\d+)(\.\d+)*$/
end
