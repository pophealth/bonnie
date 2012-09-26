class CodeSet
  include Mongoid::Document
  embedded_in :code_settable

  field :key, type: String
  field :concept, type: String
  field :oid, type: String
  field :category, type: String
  field :description, type: String
  field :organization, type: String
  field :version, type: String
  field :codes, type: Array, default: []
  field :code_set, type: String
end