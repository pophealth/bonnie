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

class @ValueSetFunctions
  test: (formData) ->
    console.log("in test(): #{formData}")
    
  showResponse: (response) ->
    console.log("show response with params")
  
  bind_add_code: ->
    $('#codes .btn').on "click", ->
      codeField = $('#codes .input-small:last').clone()
      codeField = codeField[0]  # flatten
      new_id = (Number) (codeField.id.match(/(\d+)/))[0]
      new_id++
      new_name = (Number) (codeField.name.match(/(\d+)/))[0]
      new_name++
      codeField.id = codeField.id.replace /(\d+)/, new_id
      codeField.name = codeField.name.replace /(\d+)/, new_name
      $('#codes .controls').append(codeField)
      $('#codes .controls').append("<br>")
    
  bind_submit: ->
    # options = {
    #   target: '#response',
    #   beforeSubmit: this.test,
    #   success: this.showResponse,
    #   url: '/value_sets.json',
    #   dataType: 'json'
    # }
    # 
    # $('#new_value_set').ajaxForm(options)
    
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
    
    # bind form submit button
    $('#new_value_set').on "submit", (e) ->
      e.preventDefault()
      url = '/value_sets.json'
      form = $(this)
      o = form.serializeObject()
      delete o.utf8                 # remove the attributes we don't care about
      delete o.authenticity_token   # remove the attributes we don't care about
      console.log o
      data = JSON.stringify(o)
      $.post url,
        data: data
        () -> console.log("run .post")
      return false
