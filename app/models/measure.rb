class Measure
  include Mongoid::Document

  DEFAULT_EFFECTIVE_DATE = Time.gm(2012,12,31,23,59).to_i
  TYPES = ["ep", "eh"]

  store_in collection: 'draft_measures'

  field :id, type: String
  field :endorser, type: String
  field :measure_id, type: String
  field :hqmf_id, type: String
  field :hqmf_set_id, type: String
  field :hqmf_version_number, type: Integer
  field :title, type: String
  field :description, type: String
  field :type, type: String
  field :category, type: String
  field :steward, type: String    # organization who's writing the measure
  field :episode_of_care, type: Boolean
  field :continuous_variable, type: Boolean
  field :episode_ids, type: Array # of String ids
  field :custom_functions, type: Hash # stores a custom function for a population criteria (used only in ADE_TTR for observation)

  field :published, type: Boolean
  field :publish_date, type: Date
  field :version, type: Integer

  field :population_criteria, type: Hash
  field :data_criteria, type: Hash, default: {}
  field :source_data_criteria, type: Hash, default: {}
  field :measure_period, type: Hash
  field :measure_attributes, type: Hash
  field :populations, type: Array
  field :preconditions, type: Hash

  field :value_set_oids, type: Array, default: []

  belongs_to :user
  embeds_many :publishings
  has_many :records

  scope :published, -> { where({'published'=>true}) }
  scope :by_measure_id, ->(id) { where({'measure_id'=>id }) }
  scope :by_user, ->(user) { where({'user_id'=>user.id}) }
  scope :by_type, ->(type) { where({'type'=>type}) }

  TYPE_MAP = {
    'problem' => 'conditions',
    'encounter' => 'encounters',
    'labresults' => 'results',
    'procedure' => 'procedures',
    'medication' => 'medications',
    'rx' => 'medications',
    'demographics' => 'characteristic',
    'derived' => 'derived'
  }

  # Create or increment all of the versioning information for this measure
  def publish
    self.publish_date = Time.now
    self.version ||= 0
    self.version += 1
    self.published=true
    self.publishings << as_publishing
    self.save!
  end

  def latest_version
    publishings.by_version(self.version).first
  end

  def data_criteria_by_oid
    by_oid = {}
    data_criteria.each do |key, criteria|
      by_oid[criteria["code_list_id"]] = criteria
    end
    by_oid
  end

  # Reshapes the measure into the JSON necessary to build the popHealth parameter view for stage one measures.
  # Returns a hash with population, numerator, denominator, and exclusions
  def parameter_json(population_index=0, inline=false)
    parameter_json = {}
    population_index ||= 0

    population = populations[population_index]

    title_mapping = {
      population[HQMF::PopulationCriteria::IPP] => "population",
      population[HQMF::PopulationCriteria::DENOM] => "denominator",
      population[HQMF::PopulationCriteria::NUMER] => "numerator",
      population[HQMF::PopulationCriteria::DENEX] => "exclusions",
      population[HQMF::PopulationCriteria::DENEXCEP] => "exceptions",
      population[HQMF::PopulationCriteria::MSRPOPL] => "measure population",
      population[HQMF::PopulationCriteria::OBSERV] => "measure observation"
    }
    self.population_criteria.each do |key, criteria|
      parameter_json[title_mapping[key]] = population_criteria_json(criteria, inline) if title_mapping[key]
    end

    parameter_json
  end

  def population_criteria_json(criteria, inline=false)
    {
      conjunction: "and",
      items: parse_hqmf_preconditions(criteria, inline)
    }
  end

  # Returns the hqmf-parser's ruby implementation of an HQMF document.
  # Rebuild from population_criteria, data_criteria, and measure_period JSON
  def as_hqmf_model
    json = {
      "id" => self.measure_id,
      "title" => self.title,
      "description" => self.description,
      "population_criteria" => self.population_criteria,
      "data_criteria" => self.data_criteria,
      "source_data_criteria" => self.source_data_criteria,
      "measure_period" => self.measure_period,
      "attributes" => self.measure_attributes,
      "populations" => self.populations
    }

    HQMF::Document.from_json(json)
  end

  def upsert_data_criteria(criteria, source=false)
    criteria['type'] = criteria['type'] || TYPE_MAP[criteria['standard_category']]

    edit = if source then self.source_data_criteria || {} else self.data_criteria || {} end
    edit[criteria['id']] ||= {}
    edit[criteria['id']].merge!(criteria)
    if source
      self.source_data_criteria = edit
    else
      self.data_criteria = edit
    end
  end

  def all_data_criteria
    data_criteria.merge(source_data_criteria)
  end

  def create_hqmf_preconditions(data)
    conjunction_mapping = { "and" => "allTrue", "or" => "atLeastOneTrue" }
    if data['conjunction?']
      data['preconditions'] = [
        create_hqmf_preconditions(data['preconditions'])
      ]
      self.population_criteria[data['type']] = data
    else
      data = {
        'conjunction_code' => conjunction_mapping[data['conjunction']],
        'id' => data['precondition_id'],
        'negation' => data['negation'] == true || data['negation'] == 'true',
        'preconditions' => if !data['items'].blank? then data['items'].map {|k,v| create_hqmf_preconditions(v)} end,
        'reference' => data['id'],
      }
      if !data['id']
        data['id'] = data['precondition_id'] || Moped::BSON::ObjectId.new.to_s
        if data['reference'] && self['data_criteria'][data['reference']].nil?
          upsert_data_criteria((self['source_data_criteria'][data['reference']]).merge({'id' => data['reference'] += '_' + data['id']}))
        end
      end
    end
    data
  end

  def name_precondition(id, name)
    self.preconditions ||= {}
    self.preconditions[id] = name
  end

  def value_sets
    @value_sets ||= HealthDataStandards::SVS::ValueSet.in(oid: value_set_oids).where({'_type'=>{'$ne'=>'WhiteList'}})
    @value_sets
  end

  private

  def as_publishing
    Publishing.new(self.attributes.except('_id','publishings', 'published', 'nqf_id'));
  end

  # This is a helper for parameter_json.
  # Return recursively generated JSON that can be imported into popHealth or shown as parameters in Bonnie.
  def parse_hqmf_preconditions(criteria, inline=false)
    conjunction_mapping = { "allTrue" => "and", "atLeastOneTrue" => "or" } # Used to convert to stage one, if requested in version param

    if criteria["conjunction?"] # We're at the top of the tree
      fragment = []
      criteria["preconditions"].each do |precondition|
        fragment << parse_hqmf_preconditions(precondition, inline)
      end if criteria['preconditions']
      return fragment
    else # We're somewhere in the middle
      element = {
        conjunction: conjunction_mapping[criteria["conjunction_code"]] || criteria["conjunction_code"],
        items: [],
        negation: criteria["negation"],
        precondition_id: criteria['id']
      }
      criteria["preconditions"].each do |precondition|
        if precondition["reference"] # We've hit a leaf node - This is a data criteria reference
          element[:items] << if inline
              inline_data_criteria(data_criteria[precondition["reference"]])
            else
              {id: precondition["reference"], precondition_id: precondition['id']}
            end
        end
        if precondition['preconditions']
          precondition['conjunction_code'] = 'and' if precondition["reference"]
          element[:items] << parse_hqmf_preconditions(precondition, inline)
        end
      end if criteria["preconditions"]
      return element
    end

  end

  def inline_data_criteria(current_criteria)
    temporal_references = {}
    if current_criteria['temporal_references']
      temporal_references = {
        'temporal_references' => current_criteria['temporal_references'].map {|r|
          r.merge(
            if r['reference'] != 'MeasurePeriod'
              {'reference' => inline_data_criteria(data_criteria[r['reference']])}
            else {title: 'MeasurePeriod'}
            end
          )
        }
      }
    end
    children_criteria = {}
    if current_criteria['children_criteria']
      children_criteria = {
        'children_criteria' => current_criteria['children_criteria'].map {|child|
          inline_data_criteria(data_criteria[child])
        }
      }
    end
    current_criteria.merge(temporal_references).merge(children_criteria)
  end

end
