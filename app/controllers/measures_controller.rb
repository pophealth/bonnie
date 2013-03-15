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

    format = params[:download][:format]
    zip = nil
    if format == 'qrda'
      zip = TPG::Exporter.zip_qrda_cat_1_patients({measure.measure_id => records.to_a}, [measure.as_hqmf_model])
    else
      zip = TPG::Exporter.zip(records, format)
    end


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
    @data_criteria = Measures::PatientBuilder.get_data_criteria(measure_list)
    @dropped_data_criteria = Measures::PatientBuilder.check_data_criteria!(@record, @data_criteria)
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

    patient['measure_ids'] ||= []
    patient['measure_ids'] = Array.new(patient['measure_ids']).push(@measure['measure_id']) unless patient['measure_ids'].include? @measure['measure_id']

    params['birthdate'] = Time.parse(params['birthdate']).to_i

    ['first', 'last', 'gender', 'expired', 'birthdate', 'description', 'description_category'].each {|param| patient[param] = params[param]}
    patient['ethnicity'] = {'code' => params['ethnicity'], 'name'=>ETHNICITY_NAME_MAP[params['ethnicity']], 'codeSystem' => 'CDC Race'}
    patient['race'] = {'code' => params['race'], 'name'=>RACE_NAME_MAP[params['race']], 'codeSystem' => 'CDC Race'}

    patient['source_data_criteria'] = JSON.parse(params['data_criteria'])
    patient['measure_period_start'] = params['measure_period_start'].to_i
    patient['measure_period_end'] = params['measure_period_end'].to_i

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

    Measures::PatientBuilder.rebuild_patient(patient)

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
