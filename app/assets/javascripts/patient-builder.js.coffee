###
  remove birthdate, gender, expired, clinical trial
  create unique from specific/non specific occurrences
  add time, values, fields, negation
  save new patient
###

bonnie = @bonnie || {}

class @bonnie.PatientBuilder
  constructor: (data_criteria, value_sets) ->
    @data_criteria = {}
    @selected_data_criteria = {}
    @value_sets = {}
    @value_sets[s.oid] = s for s in value_sets
    @data_criteria_counter = 0
    for key in _.keys(data_criteria)
      @data_criteria[key] = new bonnie.DataCriteria(key, data_criteria[key], @measure_period)

  nextDataCriteriaId: =>
    @data_criteria_counter+=1

  registerDataCriteria: (criteria) =>
    criteria.start_date = new Date($('#measure_period_start').val()).getTime()
    criteria.end_date = new Date($('#measure_period_start').val()).getTime()
    @selected_data_criteria[criteria.id] = criteria
    @updateTimeline()

  detachDataCriteria: (criteria) =>
    $('.paramGroup[data-criteria-id='+criteria.id+']').detach();
    delete @selected_data_criteria[criteria.id]
    $('#workspace').empty();
    @updateTimeline()

  getDateString: (date) =>
    d = new Date(date)
    val = "#{d.getFullYear()}-#{@fillZeros(d.getMonth()+1)}-#{@fillZeros(d.getDate())}T#{@fillZeros(d.getHours())}:#{@fillZeros(d.getMinutes())}:#{@fillZeros(d.getSeconds())}Z"

  fillZeros: (string) ->
    val = "0#{string}"
    val.substring(val.length-2)

  toggleDataCriteriaTree: (element) =>
    $(element.currentTarget).closest(".paramGroup").find("i").toggleClass("icon-chevron-right").toggleClass("icon-chevron-down")
    category = $(element.currentTarget).data('category');
    children = $(".#{category}_children")
    if (children.is(':visible'))
      children.hide("blind", { direction: "vertical" }, 500)
    else
      children.show("blind", { direction: "vertical" }, 500)

  timelineToDataCriteria: (data_criteria) =>
    bonnie.timeline.getBand(0).setCenterVisibleDate(new Date(data_criteria.start_date))

  highlightSelectedDataCriteria: (minDate, maxDate) =>
    container = $('#patient_data_criteria');
    children = container.children("div");
#    $('.paramGroup').removeClass('highlight')
    $('.paramItem').removeClass('highlight')
    for child in children
      dc = @selectedDataCriteria($(child).data('criteria-id'))
      dc_start = new Date(dc.start_date)
      dc_end = new Date(dc.end_date)
      if ((dc_start <= maxDate and dc_end >= minDate ))
        $(child).children('.paramItem').addClass('highlight')


  editDataCriteria: (element) =>
    leaf = $(element)

    $('.paramItem').removeClass('editing')
    leaf.children('.paramItem').addClass('editing')

    top = $('#workspace > div').css('top')
    $('#workspace').empty()
    data_criteria = @selectedDataCriteria($(element).data('criteria-id'))
    element = data_criteria.asHtml('data_criteria_edit').appendTo('#workspace')

    offset = leaf.offset().top + leaf.height()/2 - $('#workspace').offset().top - element.height()/2
    offset = 0 if offset < 0
    maxoffset = $('#measureEditContainer').height() - element.outerHeight(true) - $('#workspace').position().top - $('#workspace').outerHeight(true) + $('#workspace').height()+$('#patient_data_criteria').position().top
    offset = maxoffset if offset > maxoffset
    element.css("top", offset)
    arrowOffset = leaf.offset().top + leaf.height()/2 - element.offset().top - $('.arrow-w').outerHeight()/2
    arrowOffset = 0 if arrowOffset < 0
    $('.arrow-w').css('top', arrowOffset)
    element.css("top", top)
    element.animate({top: offset})
    $('.close_edit').click( -> $('#workspace').empty(); $('.paramItem').removeClass('editing') );

    $('#element_start').datetimepicker({
      onSelect: (selectedDate) -> $( "#element_end" ).datetimepicker('option', "minDate", new Date(selectedDate) )
    }).datetimepicker('setDate', new Date(data_criteria.start_date));

    $('#element_end').datetimepicker({
      onSelect: (selectedDate) -> $( "#element_start" ).datetimepicker( "option", "maxDate", new Date(selectedDate) )
    }).datetimepicker('setDate', new Date(data_criteria.end_date));

    $('#element_value').val(data_criteria.value)
    $('#element_value_unit').val(data_criteria.value_unit)

    $('#element_update').click(=>
      data_criteria = @selectedDataCriteria($('#element_id').val())
      data_criteria.start_date = new Date($('#element_start').val()).getTime()
      data_criteria.end_date = new Date($('#element_end').val()).getTime()
      data_criteria.value = $('#element_value').val()
      data_criteria.value_unit = $('#element_value_unit').val()
      @updateTimeline()
      @timelineToDataCriteria(data_criteria)
      $('#workspace').empty()
      $('.paramItem').removeClass('editing')
      )

  sortSelectedDataCriteria: () =>
    container = $('#patient_data_criteria');
    children = container.children("div");

    children.detach().sort((left, right) =>
      left_dc = @selectedDataCriteria($(left).data('criteria-id'))
      right_dc = @selectedDataCriteria($(right).data('criteria-id'))
      @getDateString(left_dc.start_date) > @getDateString(right_dc.start_date) ? 1 : -1;
      );
    container.append(children);



  updateTimeline: =>

    @sortSelectedDataCriteria()

    timelineData = {
    'dateTimeFormat': 'iso8601',
    'events' : []
    }

    for key in _.keys(@selected_data_criteria)
      criteria = @selectedDataCriteria(key)
      start = @getDateString(criteria.start_date)
      end = @getDateString(criteria.end_date)
      event = {'start': start, 'title': "#{criteria.category} #{criteria.status}: #{criteria.title}", 'description': "#{criteria.category} #{criteria.status}: #{criteria.title}", 'id': "#{criteria.id}"}
      event['end'] = end if start != end
      timelineData.events.push(event)

    bonnie.timelineEvents.clear();
    bonnie.timelineEvents.loadJSON(timelineData, '.');
    bonnie.timeline.layout()



  dataCriteria: (id) =>
    @data_criteria[id]
  selectedDataCriteria: (id) =>
    @selected_data_criteria[id]

  save_patient_builder: (form)->
    data_criteria = []
    $('#patient_data_criteria .paramGroup').each((i,e)=>
      data = bonnie.patientBuilder.selected_data_criteria[$(e).data('criteria-id')]
      data_criteria.push({
        id: data.source
        start_date: data.start_date
        end_date: data.end_date
        value: data.value if data.value
        value_unit: data.value_unit if data.value
      })
    );
    $(form).ajaxSubmit({
      beforeSubmit: (v) -> v.map((e) ->
        e.value = new Date(e.value).getTime() if e.name == 'birthdate'
        e
      )
      data: {
        measure_period_start: new Date($('#measure_period_start').val()).getTime()
        measure_period_end: new Date($('#measure_period_end').val()).getTime()
        data_criteria: JSON.stringify(data_criteria)
      },
      success: (r)->
        document.location.href = $(form).find('input.redirect_url[type=hidden]').val() if r
    });

class PatientBuilderPage
  constructor: (data_criteria, value_sets, patient) ->
    bonnie.patientBuilder = new bonnie.PatientBuilder(data_criteria, value_sets)
    if patient
      $(window).load(->
        for data_criteria in patient
          if data_criteria.id == 'MeasurePeriod'
            $('#measure_period_start').datetimepicker('setDate', new Date(data_criteria.start_date));
            $('#measure_period_end').datetimepicker('setDate', new Date(data_criteria.end_date));
          else
            criteria = fillDrop({target: $('#patient_data_criteria')}, {draggable: $('[data-criteria-id=' + data_criteria.id + ']')});
            criteria.start_date = data_criteria.start_date
            criteria.end_date = data_criteria.end_date
            criteria.value = data_criteria.value
            criteria.value_unit = data_criteria.value_unit
        $('#workspace .close_edit').click()
      )

  initialize: () =>
    $(document).on('click', '#dataCriteria .paramGroup', bonnie.patientBuilder.toggleDataCriteriaTree)
