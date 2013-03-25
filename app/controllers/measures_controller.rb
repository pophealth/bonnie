class MeasuresController < ApplicationController
  include Measures::DatabaseAccess
  layout :select_layout
  before_filter :authenticate_user!
  before_filter :validate_authorization!
  
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
    @population = params[:population]
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

  def update_population
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    index = params['index'].to_i
    title = params['title']
    @measure.populations[index]['title'] = title
    @measure.save!
    render partial: 'populations', locals: {measure: @measure}
  end

  def export
    measures = Measure.by_user(current_user).to_a

    file = Measures::Exporter.export_bundle(measures, true)
    version = APP_CONFIG["measures"]["version"]
    send_file file.path, :type => 'application/zip', :disposition => 'attachment', :filename => "bundle-#{version}.zip"
  end

  def load_measures

    if (params[:file])
      file = params[:file]
      Measures::Loader.load_mat_exports([file],current_user.username)
      redirect_to :measures, notice: 'Measure was successfully loaded.'
    else
      paths = params[:paths] || []
      measure_ids = params[:measure_ids] || []

      current_user.measures.each do |measure| 
        measure.value_sets.destroy_all
        HealthDataStandards::CQM::Measure.where(hqmf_id: measure.hqmf_id).destroy_all
        MONGO_DB['query_cache'].find({}).remove_all
        MONGO_DB['patient_cache'].find({}).remove_all
        MONGO_DB.command({ getlasterror: 1 })
      end

      current_user.measures.destroy_all

      job = Measures::Loader.delay(:queue => 'measure_loaders').load_paths(paths,current_user.username,true,true)
      job['measure_ids'] = measure_ids
      job.save!
      render json: {job_id: job.id}
    end

  end

  def download_measures
    data = Measures::Loader.load_from_url(params[:source_url])
    data.sort! {|l,r| l['nqf_id'] <=> r['nqf_id']}
    render :json => data
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
 
  ##################
  ## Populations
  ##################

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

  
end
