class MeasuresController < ApplicationController
  include Measures::DatabaseAccess
  layout :select_layout
  before_filter :authenticate_user!
  before_filter :validate_authorization!
  
  JAN_ONE_THREE_THOUSAND=32503698000000
  RACE_NAME_MAP={'1002-5' => 'American Indian or Alaska Native','2028-9' => 'Asian','2054-5' => 'Black or African American','2076-8' => 'Native Hawaiian or Other Pacific Islander','2106-3' => 'White','2131-1' => 'Other'}
  ETHNICITY_NAME_MAP={'2186-5'=>'Not Hispanic or Latino', '2135-2'=>'Hispanic Or Latino'}

  add_breadcrumb 'measures', "/measures"

  rescue_from Mongoid::Errors::Validations do
    render :template => "measures/edit"
  end

  def index
    @measure = Measure.new
    @measures = current_user.measures
    @all_published = Measure.published
  end

  def show
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
  end

  def show_nqf
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @contents = File.read(File.expand_path(File.join(Measures::Loader::SOURCE_PATH, "html", "#{@measure.hqmf_id}.html")))
    add_breadcrumb @measure["measure_id"], "/measures/" + @measure["measure_id"]
    add_breadcrumb 'NQF Definition', ''
  end


  def publish
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @measure.publish

    @show_published=true
    @measures = current_user.measures
    @all_published = Measure.published

    flash[:notice] = "Published #{@measure.title}."
    render :index
  end

  def published
    @measures = Measure.published.map(&:latest_version)
  end

  def new
    @measure = Measure.new
  end

  def edit
    @editing=true
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id'] + '/edit'
  end

  def create
    # Value sets
    value_set_file = params[:measure][:value_sets]
    value_set_path = value_set_file.tempfile.path
    value_set_format = HQMF::ValueSet::Parser.get_format(value_set_file.original_filename)

    # Load the actual measure
    hqmf_path = params[:measure][:hqmf].tempfile.path
    html_path = params[:measure][:html].tempfile.path

    measure = Measures::Loader.load(hqmf_path, current_user, html_path, true, nil, nil, nil, value_set_path, value_set_format)

    redirect_to edit_measure_url(measure)
  end

  def upsert_criteria
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    criteria = {"id" => params[:criteria_id]  || Moped::BSON::ObjectId.new.to_s, "type" => params['type']}
    ["title", "code_list_id", "description", "qds_data_type", 'negation_code_list_id'].each { |f| criteria[f] = params[f] if !params[f].blank?}


    # Do that HQMF Processing
    criteria = {'id' => criteria['id'] }.merge JSON.parse(HQMF::DataCriteria.create_from_category(criteria['id'], criteria['title'], criteria['description'], criteria['code_list_id'], params['category'], params['subcategory'], !criteria['negation'].blank?, criteria['negation_code_list_id']).to_json.to_json).flatten[1]

    ["display_name"].each { |f| criteria[f] = params[f] if !params[f].nil?}
    ["property", "children_criteria"].each { |f| criteria[f] = params[f] if !params[f].blank?}

    criteria['value'] = if params['value'] then JSON.parse(params['value']) else nil end
    criteria['temporal_references'] = if params['temporal_references'] then JSON.parse(params['temporal_references']) else nil end
    criteria['subset_operators'] = if params['subset_operators'] then JSON.parse(params['subset_operators']) else nil end
    criteria['field_values'] = if params['field_values'] then JSON.parse(params['field_values']) else nil end

    @measure.upsert_data_criteria(criteria, params['source'])
    render :json => @measure.data_criteria[criteria['id']] if @measure.save
  end

  def update
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @measure.update_attributes!(params[:measure])

    redirect_to @measure, notice: 'Measure was successfully updated.'
  end

  def destroy
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @measure.destroy

    redirect_to measures_url
  end

  def select_layout
    case @_action_name
    when 'show_nqf'
      "empty"
    else
      'application'
      #"measure_page"
    end
  end

  def validate_authorization!
    authorize! :manage, Measure
  end

  def definition
    measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    population_index = params[:population].to_i if params[:population]
    population = measure.parameter_json(population_index)
    render :json => population
  end

  def population_criteria_definition
    measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    population = measure.population_criteria_json(measure.population_criteria[params[:key]])
    render :json => population
  end

  def export
    measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first

    file = Measures::Exporter.export_bundle([measure], true)
    send_file file.path, :type => 'application/zip', :disposition => 'attachment', :filename => "bundle-#{measure.id}.zip"
  end

  def export_all
    measures = Measure.by_user(current_user).to_a

    file = Measures::Exporter.export_bundle(measures, true)
    version = APP_CONFIG["measures"]["version"]
    send_file file.path, :type => 'application/zip', :disposition => 'attachment', :filename => "bundle-#{version}.zip"
  end

  def download_patients
    measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    
    records = []
    @measure_patients = !params[:measure_patients].nil?
    if (@measure_patients)
      records = measure.records
    else
      records = Record.all
    end
    
    zip = TPG::Exporter.zip(records, params[:download][:format])


    send_file zip.path, :type => 'application/zip', :disposition => 'attachment', :filename => "patients.zip"
  end

  def debug
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @patient = Record.find(params[:record_id])
    @population = (params[:population] || 0).to_i

    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
    add_breadcrumb 'Test', '/measures/' + @measure['measure_id'] + '/test'
    add_breadcrumb 'Inspect Patient', ''

    respond_to do |wants|
      wants.html do
        @js = Measures::Calculator.execution_logic(@measure, @population, true)
      end
      wants.js do
        @measure_js = Measures::Calculator.execution_logic(@measure, @population, true)
        render :content_type => "application/javascript"
      end
    end
  end
  
  def debug_libraries
    respond_to do |wants|
      wants.js do
        @libraries = Measures::Calculator.library_functions
        render :content_type => "application/javascript"
      end
    end
  end

  def test
    @population = params[:population] || 0
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    
    @measure_patients = !params[:measure_patients].nil?
      
    @patient_names = (Record.all.order_by(:last.asc)).collect {|r| [
      "#{r[:last]}, #{r[:first]}",
      r[:_id].to_s,
      {'description' => r['description'], 'category' => r['description_category']},
      {'start' => r['measure_period_start'], 'end' => r['measure_period_end']},
      r['measure_id']
    ]}

    # we need to manipulate params[:patients] but it's immutable?
    if params[:patients]
      # full of {"4fa98074431a5fb25f000132"=>1} etc
      @patients_posted = params[:patients].collect {|p| { p[0] => p[1].to_i } }
      # reject patients that were not posted (checkbox not checked)
      @patients_posted.reject! {|p| p.flatten[1] == 0}
      # now full of ["4fa98074431a5fb25f000132"]
      @patients_posted = @patients_posted.collect {|p| p.keys}.flatten
    end
    
    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
    add_breadcrumb 'Test', '/measures/' + @measure['measure_id'] + '/test'
  end

  def debug_rationale
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @patient = Record.find(params[:record_id])
    @population = (params[:population] || 0).to_i
    template = Measures::HTML::Writer.generate_nqf_template(@measure, @measure.populations[@population])
    @contents = Measures::HTML::Writer.finalize_template_body(template,"getRationale()",@patient)
  end

  ####
  ## POPULATIONS
  ####
  def update_population
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    index = params['index'].to_i
    title = params['title']
    @measure.populations[index]['title'] = title
    @measure.save!
    render partial: 'populations', locals: {measure: @measure}
  end

  def delete_population
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    index = params['index'].to_i
    @measure.populations.delete_at(index)
    @measure.save!
    render partial: 'populations', locals: {measure: @measure}
  end
  def add_population
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    population = {}
    population['title']= params['title']

    HQMF::PopulationCriteria::ALL_POPULATION_CODES.each do |key|
      population[key]= params[key] unless params[key].empty?
    end

    if (population['NUMER'] and population['IPP'])
      @measure.populations << population
      @measure.save!
    else
      raise "numerator and initial population must be provided"
    end


    render partial: 'populations', locals: {measure: @measure}
  end
  def update_population_criteria
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @measure.create_hqmf_preconditions(params['data'])
    @measure.save!
    render :json => {
      'population_criteria' => {{
        HQMF::PopulationCriteria::IPP => "population",
        HQMF::PopulationCriteria::DENOM => "denominator",
        HQMF::PopulationCriteria::NUMER => "numerator",
        HQMF::PopulationCriteria::DENEX => "exclusions",
        HQMF::PopulationCriteria::DENEXCEP => "denexcep"
      }[params['data']['type']] => @measure.population_criteria_json(@measure.population_criteria[params['data']['type']])},
      'data_criteria' => @measure.data_criteria
    }
  end

  def name_precondition
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @measure.name_precondition(params[:precondition_id], params[:name])
    render :json => @measure.save!
  end

  def save_data_criteria
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @measure.data_criteria[params[:criteria_id]]['saved'] = true
    render :json => @measure.save!
  end
  
  def patient_builder
    
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @record = Record.where({'_id' => params[:patient_id]}).first || {}
    measure_list = (@record['measure_ids'] || []) << @measure['measure_id']
    
    @data_criteria = Hash[
      *Measure.where({'measure_id' => {'$in' => measure_list}}).map{|m|
        m.source_data_criteria.reject{|k,v|
          ['patient_characteristic_birthdate','patient_characteristic_gender', 'patient_characteristic_expired'].include?(v['definition'])
        }.each{|k,v|
          v['title'] += ' (' + m.measure_id + ')'
        }
      }.map(&:to_a).flatten
    ]
    
    @dropped_data_criteria = []
    if (@record.respond_to? :source_data_criteria)
      
      # check to see if there are any data criteria that we cannot find.  If there are, we want to remove them.
      dropped_source_criteria = @record.source_data_criteria.select {|e| @data_criteria[e['id']].nil? && e['id'] != 'MeasurePeriod' }
      dropped_source_criteria.each do |dc|
        alternates = @data_criteria.select {|key,value| value['code_list_id'] == dc['oid']}.keys
        if (!alternates.empty?)
          alternate = (alternates.sort {|left, right| Text::Levenshtein.distance(left, dc['id']) <=> Text::Levenshtein.distance(right, dc['id'])}).first
          # update the source data criteria to set the alternate id with the closes id and a matching code set id
          dc['id'] = alternate
        end
      end

      dropped_ids = (@record.source_data_criteria.select {|e| @data_criteria[e['id']].nil? && e['id'] != 'MeasurePeriod' }).map {|dc| dc['id'] }
      
      # fix values that are not arrays
      @record.source_data_criteria.each do |dc|
        if (!dc['value'].nil? and !dc['value'].is_a? Array)
          dc['value'] = [dc['value']]
        end
      end
      
      @record.source_data_criteria.delete_if {|dc| dropped = dropped_ids.include? dc['id']; @dropped_data_criteria << dc if dropped; dropped}
      
      # change children into parents
      parent_map = JSON.parse(File.read('./parent_oid_map.json')) if File.exists?('./parent_oid_map.json')
      @record.source_data_criteria.each do |dc|
        if dc['value']
          dc['value'].each do |value|
            if value['code_list_id'] and parent_map[value['code_list_id']]
              value['code_list_id'] = parent_map[value['code_list_id']]
            end
          end
          
        end
        if dc['negation_code_list_id'] && parent_map[dc['negation_code_list_id']]
          dc['negation_code_list_id'] = parent_map[dc['negation_code_list_id']]
        end
        if dc['field_values']
          dc['field_values'].each do |key, value|
            if value['code_list_id'] and parent_map[value['code_list_id']]
              value['code_list_id'] = parent_map[value['code_list_id']]
            end
          end
          
        end
        
      end if parent_map
      
      
    end
    
    @value_sets = Measure.where({'measure_id' => {'$in' => measure_list}}).map{|m| m.value_sets}.flatten(1).uniq

    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
    add_breadcrumb 'Test', '/measures/' + @measure['measure_id'] + '/test'
    add_breadcrumb 'Patient Builder', '/measures/' + @measure['measure_id'] + '/patient_builder'
  end

  def make_patient
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first

    patient = Record.where({'_id' => params['record_id']}).first || HQMF::Generator.create_base_patient(params.select{|k| ['first', 'last', 'gender', 'expired', 'birthdate'].include? k })

    if (params['clone'])
      patient = Record.new(patient.attributes.except('_id'));
      patient.save!
    end

    # clear out patient data
    if (patient.id)
      ['allergies', 'care_goals', 'conditions', 'encounters', 'immunizations', 'medical_equipment', 'medications', 'procedures', 'results', 'social_history', 'vital_signs'].each do |section|
        patient[section] = [] if patient[section]
      end
      patient.medical_record_number ||= Digest::MD5.hexdigest("#{patient.first} #{patient.last}")
      patient.save!
    end

    patient['measure_ids'] ||= []
    patient['measure_ids'] = Array.new(patient['measure_ids']).push(@measure['measure_id']) unless patient['measure_ids'].include? @measure['measure_id']

    values = Hash[
      *Measure.where({'measure_id' => {'$in' => patient['measure_ids'] || []}}).map{|m|
        m.value_sets.map do |value_set|
          preferred_set = WhiteList.where(:oid => value_set.oid).first
          
          if preferred_set.nil?
            concept = Concept.any_in(oids: value_set.oid).first
            preferred_set = concept.clone_and_filter(value_set) if concept.present?
          end
          preferred_set ||= value_set

          [value_set.oid, preferred_set]
        end
      }.map(&:to_a).flatten
    ]

    params['birthdate'] = params['birthdate'].to_i / 1000

    @data_criteria = Hash[
      *Measure.where({'measure_id' => {'$in' => patient['measure_ids'] || []}}).map{|m|
        m.source_data_criteria.reject{|k,v|
          ['patient_characteristic_birthdate','patient_characteristic_gender', 'patient_characteristic_expired'].include?(v['definition'])
        }
      }.map(&:to_a).flatten
    ]
    
    

    ['first', 'last', 'gender', 'expired', 'birthdate', 'description', 'description_category'].each {|param| patient[param] = params[param]}
    patient['ethnicity'] = {'code' => params['ethnicity'], 'name'=>ETHNICITY_NAME_MAP[params['ethnicity']], 'codeSystem' => 'CDC Race'}
    patient['race'] = {'code' => params['race'], 'name'=>RACE_NAME_MAP[params['race']], 'codeSystem' => 'CDC Race'}

    insurance_types = {
      'MA' => 'Medicare',
      'MC' => 'Medicaid',
      'OT' => 'Other'
    }
    insurance_provider = InsuranceProvider.new
    insurance_provider.type = params['payer']
    insurance_provider.member_id = '1234567890'
    insurance_provider.name = insurance_types[params['payer']]
    insurance_provider.financial_responsibility_type = {'code' => 'SELF', 'codeSystem' => 'HL7 Relationship Code'}
    insurance_provider.start_time = Time.new(2008,1,1).to_i
    insurance_provider.payer = Organization.new
    insurance_provider.payer.name = insurance_provider.name
    patient.insurance_providers = [insurance_provider]

    patient['source_data_criteria'] = JSON.parse(params['data_criteria'])
    patient['measure_period_start'] = params['measure_period_start'].to_i
    patient['measure_period_end'] = params['measure_period_end'].to_i
    
    JSON.parse(params['data_criteria']).each {|v|
      data_criteria = HQMF::DataCriteria.from_json(v['id'], @data_criteria[v['id']])
      data_criteria.values = []
      result_vals = v['value'] || []
      result_vals = [result_vals] if !result_vals.nil? and !result_vals.is_a? Array 
      result_vals.each do |value|
        data_criteria.values << (value['type'] == 'CD' ? HQMF::Coded.new('CD', nil, nil, value['code_list_id']) : HQMF::Range.from_json('low' => {'value' => value['value'], 'unit' => value['unit']}))
      end if v['value']
      v['field_values'].each do |key, value|
        data_criteria.field_values ||= {}
        value['value'] = Time.strptime(value['value'],"%m/%d/%Y %H:%M").to_time.strftime('%Y%m%d%H%M%S') if (value['type'] == 'TS') 
        data_criteria.field_values[key] = HQMF::DataCriteria.convert_value(value)
      end if v['field_values']
      if v['negation'] == 'true'
        data_criteria.negation = true
        data_criteria.negation_code_list_id = v['negation_code_list_id']
      end
      low = {'value' => Time.at(v['start_date'] / 1000).strftime('%Y%m%d%H%M%S'), 'type'=>'TS' }
      high = {'value' => Time.at(v['end_date'] / 1000).strftime('%Y%m%d%H%M%S'), 'type'=>'TS' }
      high = nil if v['end_date'] == JAN_ONE_THREE_THOUSAND

      data_criteria.modify_patient(patient, HQMF::Range.from_json({'low' => low,'high' => high}), values.values)
    }

    patient['source_data_criteria'].push({'id' => 'MeasurePeriod', 'start_date' => params['measure_period_start'].to_i, 'end_date' => params['measure_period_end'].to_i})

    if @measure.records.include? patient
      render :json => patient.save!
    else
      @measure.records.push(patient)
      render :json => @measure.save!
    end
  end

  def delete_patient
    Record.find(params['victim']).delete
    render :json => {deleted: params['victim']}
  end

  def matrix
    add_breadcrumb 'Matrix', '/measures/matrix'
  end

  def generate_matrix
    (params[:id] ? [current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first] : Measure.all.to_a).each{|m|
      MONGO_DB['query_cache'].find({'measure_id' => m['hqmf_id']}).remove_all
      MONGO_DB['patient_cache'].find({'value.measure_id' => m['hqmf_id']}).remove_all
      (m['populations'].length > 1 ? ('a'..'zz').to_a.first(m['populations'].length) : [nil]).each{|sub_id|
        p 'Calculating measure ' + m.measure_id + (sub_id || '') + " (#{m['hqmf_id']})"
        oid_dictionary = HQMF2JS::Generator::CodesToJson.hash_to_js(Measures::Calculator.measure_codes(m))
        options = {'effective_date' => (params['effective_date'] || Measure::DEFAULT_EFFECTIVE_DATE).to_i, 'oid_dictionary' => oid_dictionary }
        qr = QME::QualityReport.new(m['hqmf_id'], sub_id, options)
        qr.calculate(false) unless qr.calculated?
      }
    }
    redirect_to :action => 'matrix'
  end

  def matrix_data
    select = {}
    ['IPP', 'DENOM', 'NUMER', 'DENEXCEP', 'DENEX', 'MSRPOPL', 'values', 'first', 'last', 'gender', 'measure_id', 'birthdate', 'patient_id', 'sub_id', 'nqf_id'].each {|k| select['value.'+k]=1 }
    render :json => MONGO_DB['patient_cache'].find({}).select(select)
  end

  def download_measures
    data = Measures::Loader.load_from_url(params[:source_url])
    data.sort! {|l,r| l['nqf_id'] <=> r['nqf_id']}
    render :json => data
  end

  def load_measures
    paths = params[:paths] || []
    measure_ids = params[:measure_ids] || []

    current_user.measures.each {|measure| measure.value_sets.destroy_all}
    current_user.measures.destroy_all

    job = Measures::Loader.delay(:queue => 'measure_loaders').load_paths(paths,current_user.username)
    job['measure_ids'] = measure_ids
    job.save!
    render json: {job_id: job.id}
  end

  def poll_load_job_status
    result = {}
    job = Delayed::Job.find(params[:job_id]) rescue nil
    if job
      measure_ids = job['measure_ids']
      total = measure_ids.length
      if total > 0
        found = Measure.where({hqmf_id: {'$in'=>measure_ids}}).count
        result['percent'] = ((found / (total * 1.0)) * 100).ceil
      else
        result['percent'] = 100
      end
    else
      result['percent'] = 100
    end
    render json: result
  end

  
end
