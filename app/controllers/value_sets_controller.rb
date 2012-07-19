require 'json'

class ValueSetsController < ApplicationController
  skip_authorization_check
  
  add_breadcrumb 'value_sets', ""
  
  def index
    @value_sets = ValueSet.limit(5)
  end
  
  def show
    @value_set = ValueSet.find(params[:id])
    @value_set_json = JSON.pretty_generate(JSON.parse(@value_set.to_json))
  end
  
  def edit
    @value_set = ValueSet.find(params[:id])
  end
  
  def new
    @value_set = ValueSet.new
  end
  
  def create
    render :template => 'value_sets/new'
  end
  
end
