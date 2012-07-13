class MeasuresController < ApplicationController

  layout :select_layout
  before_filter :authenticate_user!
  before_filter :validate_authorization!

  add_breadcrumb 'measures', ""

  rescue_from Mongoid::Errors::Validations do
    render :template => "measures/edit"
  end

  def index
    @measure = Measure.new
    @measures = current_user.measures
    @all_published = Measure.published
  end

  def show
    @measure = Measure.find(params[:id])
  end

  def show_nqf
    @measure = Measure.find(params[:id])
    @contents = File.read(File.expand_path(File.join('.','test','fixtures','measure-defs',@measure.measure_id,"#{@measure.measure_id}.html")))
  end

  def publish
    @measure = Measure.find(params[:id])
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
    @measure = Measure.find(params[:id])
  end

  def create

    # Value sets
    value_set_file = params[:measure][:value_sets]
    value_set_path = value_set_file.tempfile.path
    value_set_format = HQMF::ValueSet::Parser.get_format(value_set_file.original_filename)

    hqmf_path = params[:measure][:hqmf].tempfile.path

    measure = Measures::Loader.load(hqmf_path, value_set_path, current_user, value_set_format)

    redirect_to edit_measure_url(measure)
  end

  def upsert_criteria
    @measure = Measure.find(params[:id])
    criteria = {"id" => params[:criteria_id], "type" => params['type']}
    ["status", "value", "standard_category", "qds_data_type"].each { |f| criteria[f] = params[f]}
    ["title", "code_list_id", "property", "children_criteria", "description"].each { |f| criteria[f] = params[f] if params[f]}
    criteria['temporal_references'] = JSON.parse(params['temporal_references']) if params['temporal_references']
    criteria['subset_operators'] = JSON.parse(params['subset_operators']) if params['subset_operators']
    @measure.upsert_data_criteria(criteria, params['source'])
    render :json => criteria if @measure.save
  end

  def update
    @measure = Measure.find(params[:id])
    @measure.update_attributes!(params[:measure])

    redirect_to @measure, notice: 'Measure was successfully updated.'
  end

  def destroy
    @measure = Measure.find(params[:id])
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
    measure = Measure.find(params[:id])
    population_index = params[:population].to_i if params[:population]
    population = measure.parameter_json(population_index)
    render :json => population
  end

  def population_criteria_definition
    measure = Measure.find(params[:id])
    population = measure.population_criteria_json(measure.population_criteria[params[:key]])
    render :json => population
  end

  def export
    measure = Measure.find(params[:id])

    file = Tempfile.new(["#{measure.id}-#{Time.now.to_i}", ".zip"])
    Measures::Exporter.export(file, [measure])

    send_file file.path, :type => 'application/zip', :disposition => 'attachment', :filename => "measures.zip"
  end

  def export_all
    measures = Measure.by_user(current_user)

    file = Tempfile.new(["#{current_user.id}-#{Time.now.to_i}", ".zip"])
    Measures::Exporter.export(file, measures)

    send_file file.path, :type => 'application/zip', :disposition => 'attachment', :filename => "measures.zip"
  end

  def debug
    @measure = Measure.find(params[:id])
    @patient = Record.find(params[:record_id])
    render "measures/debug"
  end

  def test
    @measure = Measure.find(params[:id])
    @patient_names = Record.all.entries.collect {|r| ["#{r[:first]} #{r[:last]}", r[:_id].to_s] }
    # binding.pry

    # we need to manipulate params[:patients] but it's immutable?
    if params[:patients]
      # full of {"4fa98074431a5fb25f000132"=>1} etc
      @patients_posted = params[:patients].collect {|p| { p[0] => p[1].to_i } }
      # reject patients that were not posted (checkbox not checked)
      @patients_posted.reject! {|p| p.flatten[1] == 0}
      # now full of ["4fa98074431a5fb25f000132"]
      @patients_posted = @patients_posted.collect {|p| p.keys}.flatten
    end
  end

  ####
  ## POPULATIONS
  ####
  def update_population
    @measure = Measure.find(params[:id])
    index = params['index'].to_i
    title = params['title']
    @measure.populations[index]['title'] = title
    @measure.save!
    render partial: 'populations', locals: {measure: @measure}
  end

  def delete_population
    @measure = Measure.find(params[:id])
    index = params['index'].to_i
    @measure.populations.delete_at(index)
    @measure.save!
    render partial: 'populations', locals: {measure: @measure}
  end
  def add_population
    @measure = Measure.find(params[:id])
    population = {}
    population['title']= params['title']

    ['IPP','DENOM','NUMER','EXCL','DENEXCEP'].each do |key|
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
    @measure = Measure.find(params[:id])
    @measure.create_hqmf_preconditions(params['data'])
    @measure.save!
  end
end
