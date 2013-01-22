class ValueSetsController < ApplicationController
  respond_to :html, :json, :js
  skip_authorization_check
  
  add_breadcrumb 'value_sets', ""
  
  def index
    @value_sets = HealthDataStandards::SVS::ValueSet.all
  end
  
  def show
    @value_set = HealthDataStandards::SVS::ValueSet.find(params[:id])
    respond_with do |format|
      format.json {
        render :json => @value_set
      }
      format.html {
        @value_set_html = JSON.pretty_generate(JSON.parse(@value_set.to_json))
      }
    end
  end
  
  def edit
    @value_set = HealthDataStandards::SVS::ValueSet.find(params[:id])
  end
  
  def new
    @value_set = HealthDataStandards::SVS::ValueSet.new
  end
  
  def create
    respond_with do |format|
      format.json {
        # very important to render json here and not text
        # even when debugging because ajaxForm plugin will break
        json_form = JSON.parse(params[:data].to_json)
        @value_set = HealthDataStandards::SVS::ValueSet.new json_form
        if @value_set.save
          render :json => { :message => "success", :redirect => value_set_url(@value_set) }
        else
          render :json => { :message => "failed", :errors => @value_set.errors }
        end
        # redirect_to :action => 'show', :id => vs.id
      }
    end
  end
  
  # handle updates, e.g. from the edit form
  def update
    respond_with do |format|
      format.json {
        id = params["id"]
        
        # delete form data we don't need
        params.delete("id")
        params.delete("format")
        params.delete("action")
        params.delete("controller")
        
        vs = HealthDataStandards::SVS::ValueSet.find(id)
        # Whitelist necessary here.  When passing in code_sets it breaks update_attributes.
        whitelist = [:oid, :description, :category, :concept, :organization, :version, :key]
        # splat needed below to flatten attributes to slice()
        if !vs.update_attributes(params.slice(*whitelist))
          render :json => {:message => "error", :errors => vs.errors}
        end
      
        if params.keys.include?("code_sets")
          # symbolize our params
          sliced = params.slice(*whitelist)
          params_syms = {}
          sliced.map {|k,v| params_syms[k.to_sym] = v }
          
          # our form has embedded code_sets so now we need to add them
          form_code_sets = params["code_sets"].keys.collect {|i| params["code_sets"][i]}
          
          # this was a pain: embedded docs were not saving right
          vs.update_attributes(:code_sets => form_code_sets)
          vs.save
        else
          # our form has no embedded code_sets so delete them all
          vs.code_sets.delete_all
          vs.code_sets = []
        end
        
        if vs.save
          flash[:notice] = "you just updated over ajax..."
          render :json => {:message => "success"}
        else
          render :json => {:message => "error", :errors => vs.errors}
        end
      }
    end
  end
  
end
