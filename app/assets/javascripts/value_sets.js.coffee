# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

# scope for debug in browser console
form = ""

$ ->
	codeField = $(".codeField:last").clone()
	$("#addCode").on "click", ->
		d= new Date()
		n= d.valueOf()
		codeField.attr("id", "value_set_#{n}")
		codeField.attr("value", "")
		$("#codes").append(codeField.clone())
		return false

# namespace the javascript functions inside a class
class ValueSetFunctions
  # method takes input[0] and returns input[1]
  # used for cloning elements on form
  increment_form_id: (string) ->
    new_id = (Number) (string.match(/\[(\d+)\]/))[1]
    new_id++
    return new_id

  # method takes value_set[code_sets[0]][category] and returns value_set[code_sets[1]][category]
  # used for cloning elements on form  
  increment_form_name: (string) ->
    matches = string.match(/\[(\d+)\]/g)
    last_match = matches[matches.length - 1]
    new_id = (Number) (last_match.match(/\[(\d+)\]/))[1]
    new_id++
    return new_id    
  
  bind_add_code: ->
    # fat arrow important below for the 'this' within the onClick
    $('#codes .btn').on "click", =>
      codeField = $('#codes .input-small:last').clone()[0]
      new_id = this.increment_form_id(codeField.id)
      codeField.id = codeField.id.replace /\[(\d+)\]/, "[#{new_id}]"
      codeField.name = codeField.name.replace /\[(\d+)\]\]$/, "[#{new_id}]]"
      $('#codes .controls').append(codeField)
      $('#codes .controls').append("<br>")
    
  bind_add_value_set: ->
    # bind form submit button
    $('#new-value-set').on "click", (e) ->      
      # extend jQuery to include a serializeObject function for the form submission
      $ = jQuery
      $.extend $.fn,
        serializeObject: () ->	
          e = $(this)
          a = e.serializeArray()
          o = {}

          $.each a, ->
            if o[this.name] != undefined
              console.log("this")
              o[this.name] = [o[this.name]] if !o[this.name].push
              o[this.name].push(this.value || '')
            else
              new_key = this.name.match(/\[(.*)\]/)
              o[this.name] = this.value || ''
          return o
      
      # e.preventDefault()
      url = '/value_sets.json'
      form = $("backbone-form")
      o = form.serializeObject()
      delete o.utf8                 # remove the attributes we don't care about
      delete o.authenticity_token   # remove the attributes we don't care about
      console.log o
      data = JSON.stringify(o)
      $.post url,
        data: data
        # () -> console.log("run .post")
      # return false
      
  bind_add_code_set: ->
    # fat arrow => very important here so the this in the onClick references the instance variable
    $('#code_sets .btn').on "click", =>
      code_set_elements = $('#code_sets div:first').clone()[0]
      new_id = this.increment_form_id(code_set_elements.id)
      code_set_elements.id = code_set_elements.id.replace /\[(\d+)\]/, "[#{new_id}]"
      
      # recurse through form elements and replace for, id and name strings with incremented values
      # $('#code_sets').append("<%= escape_javascript(render :partial => 'posts/comment', :locals => { :comment => @comment }) %>");
      # $('#code_sets').append(<%= escape_javascript(render(:partial => "code_set", locals: {f: f, code_set_id: 0}))%>)
      $.getJSON "/value_sets/new.js?code_set_id=1", (code_set) ->
        $('#code_sets').append(code_set)
      # $('<%= escape_javascript(render(:partial => "code_set", locals: {f: f, code_set_id: 0}))%>').appendTo

  # create a form using the backbone-form plugin for the new action
  new_form: ->
    validate_oid = new RegExp("\d+\.\d+")
    # Use BootstrapModal for object List editor
    Backbone.Form.editors.List.Modal.ModalAdapter = Backbone.BootstrapModal;

    # Main model definition
    ValueSet = Backbone.DeepModel.extend({
        schema: {
            oid: { validators: [validate_oid] },
            description: 'Text',
            category: { type: 'Select', options: ['encounter', 'procedure', 'communication'] },
            concept: 'Text',
            organization: 'Text',
            version: 'Text',
            key: 'Text',
            code_sets:    { type: 'List', itemType: 'Object', subSchema: {
                code_set: { validators: ['required'] },
                category:      { type: 'Select', options: ['encounter', 'procedure', 'communication'] },
                concept: 'Text',
                description: 'Text',
                codes:      { type: 'List' },
                key: 'Text',
                oid: 'Text',
                organization: 'Text',
                version: 'Text'
            }}
        }
    })
    
    value_set = new ValueSet({
            oid: '1.2.3',
            description: 'description',
            category: 'procedure',
            concept: 'concept',
            organization: 'organization',
            version: 'version',
            key: 'key',
            code_sets: [
                { code_set: 'ICD-9-CM', category: 'category', codes: [1,2] }
            ]
    })
    
    form = new Backbone.Form({ model: value_set }).render()
    $('#backbone-form').prepend(form.el)
    $('#new-value-set').on "click", (e) ->
      data = form.getValue();
      console.log data
      url = '/value_sets.json'
      $.post url,
        data: data
    
