
bonnie = @bonnie || {}

class @bonnie.Debug
  append_div: (div, message) ->
    div.append(message)
    div.append('\n')

  execute: (measure_id, population, patient) ->
    executors[measure_id][population].calculate(patient);

  update_log: ->
    log_element = $('#log')
    emitted[0].logger = Logger.logger
    for e in emitted[0].logger
      @append_div(log_element, e)

  clear_log: ->
    emitted[0].logger = []
    Logger.logger = []
    $('#log').empty()

  executePopulation: (population, patient_api) ->
    @clear_log();
    @executeIfAvailable(population, patient_api)
    emitted[0].logger = Logger.logger
    @update_log()

  executeIfAvailable: (optionalFunction, arg) ->
    if (typeof(optionalFunction)=='function')
      optionalFunction(arg)
    else
      false


class @bonnie.DebugInspectPage

  init: (patient_api) ->
    @debug = new bonnie.Debug()
    code_element = $('.CodeRay')
    code_element.hide()
    log_element = $('#log')

    $("#run_numerator_link").click (event) =>
      @debug.executePopulation(hqmfjs.NUMER, patient_api)

    $('#run_denominator_link').click (event) =>
      @debug.executePopulation(hqmfjs.DENOM, patient_api)

    $("#run_ipp_link").click (event) =>
      @debug.executePopulation(hqmfjs.IPP, patient_api)

    $("#run_exclusions_link").click (event) =>
      @debug.executePopulation(hqmfjs.DENEX, patient_api)

    $("#run_exceptions_link").click (event) =>
      @debug.executePopulation(hqmfjs.DENEXCEP, patient_api)

    $('#toggle_code_link').click (event) ->
      if (code_element.is(":visible") == true)
        code_element.hide()
        log_element.show()
      else
        code_element.show()
        log_element.hide()

class @bonnie.DebugTestPage

  init: () ->
    $('.patient_info.icon-info-sign').popover()
    $('#calculate_btn').click(=>
      $(window)[0].location.search = "population=#{@population()}&calculate=true"
    )

  population: () ->
    $('#population_selector').val()

  calculate: (measure_id, population, patients) ->
    @debug = new bonnie.Debug()
    for patient in patients
      @debug.execute(measure_id, population, patient)
    @populate_table()

  populate_table: () ->
    # column totals
    categories = {
      IPP:      {total: 0, color: '#EEEEEE'}, 
      DENOM:    {total: 0, color: '#99CCFF'}, 
      NUMER:    {total: 0, color: '#CCFFCC'}, 
      DENEX:    {total: 0, color: '#FFCC99'}, 
      DENEXCEP: {total: 0, color: '#F06560'}, 
      MSRPOPL:    {total: 0, color: '#CCFFCC'}, 
    }
    keys = _.keys(categories)

    for e in emitted
      # select the row with the patient id
      row = $('#patient_' + e.patient_id)

      for key in keys
        if e[key]
          value = e[key]
          categories[key]['total'] += value
          cell = $(row).children(".#{key}")
          cell.css('background-color', categories[key]['color'])
          cell.html('&#x2713;')
          values = ''
          values += "(#{value})" if (value > 1)
          values += ' [' + e.values.join(',') + ']' if (e.values and e.values.length > 0) if key == 'MSRPOPL'
          cell.html('&#x2713;' + values)

    total_row = $('#patients').find('.total')
    for key in keys
      total_row.children(".#{key}").html(categories[key]['total'])
