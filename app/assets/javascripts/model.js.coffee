bonnie = @bonnie || {}

class @bonnie.TemporalReference
  constructor: (temporal_reference) ->
    @range = new bonnie.Range(temporal_reference.range) if temporal_reference.range
    @reference = temporal_reference.reference
    @type = temporal_reference.type
    @type_decoder = {'DURING':'During','SBS':'Starts Before Start of','SAS':'Starts After Start of','SBE':'Starts Before or During','SAE':'Starts After End of','EBS':'Ends Before Start of','EAS':'Ends During or After'
                     ,'EBE':'Ends Before or During','EAE':'Ends After End of','SDU':'Starts During','EDU':'Ends During','ECW':'Ends Concurrent with','SCW':'Starts Concurrent with','CONCURRENT':'Concurrent with'}
  offset_text: =>
    if(@range)
      @range.text(true)
    else
      ''
  type_text: =>
    @type_decoder[@type]

class @bonnie.SubsetOperator
  constructor: (subset_operator) ->
    @range = new bonnie.Range(subset_operator.value) if subset_operator.value
    @type = subset_operator.type
    @type_decoder = {'COUNT':'count', 'FIRST':'first', 'SECOND':'second', 'THIRD':'third', 'FOURTH':'fourth', 'FIFTH':'fifth', 'RECENT':'most recent', 'LAST':'last', 'MIN':'min', 'MAX':'max'}

  title: =>
    range = " #{@range.text()}" if @range
    "#{@type_decoder[@type]}#{range || ''} of"

class @bonnie.DataCriteria
  constructor: (id, criteria, measure_period) ->
    @source = criteria
    @id = id
    @measure_period = measure_period
    @oid = criteria.code_list_id
    @property = criteria.property
    @title = criteria.title
    @type = criteria.type
    @definition = criteria.definition
    @display_name = criteria.display_name
    @field_values = criteria.field_values
    @specific_occurrence = criteria.specific_occurrence
    @negation = criteria.negation
    @negation_code_list_id = criteria.negation_code_list_id
    if @field_values?
      for key in _.keys(@field_values)
        value = @field_values[key]
        if value?
          value = new bonnie.Range(value) if value.type == 'IVL_PQ'
          value = new bonnie.Value(value) if value.type == 'PQ'
          value = new bonnie.Coded(value) if value.type == 'CD'
        @field_values[key] = value

    if criteria.value
      @value = new bonnie.Range(criteria.value) if criteria.value.type == 'IVL_PQ'
      @value = new bonnie.Value(criteria.value) if criteria.value.type == 'PQ'
      @value = new bonnie.Coded(criteria.value) if criteria.value.type == 'CD'
      @value = new bonnie.AnyNonNull(criteria.value) if criteria.value.type == 'ANYNonNull'
    @category = this.buildCategory()
    @status = criteria.status
    @children_criteria = criteria.children_criteria
    @derivation_operator = criteria.derivation_operator
    @temporal_references = []
    if criteria.temporal_references
      for temporal in criteria.temporal_references
        @temporal_references.push(new bonnie.TemporalReference(temporal))
    @subset_operators = []
    if criteria.subset_operators
      for subset in criteria.subset_operators
        @subset_operators.push(new bonnie.SubsetOperator(subset))

    @temporalText = this.temporalText(measure_period)

  duplicate: (new_id) =>
    new bonnie.DataCriteria(new_id, @source, @measure_period)

  asHtml: (template) =>
    bonnie.template(template,this)

  temporalText: (measure_period) =>
    text = ''
    for temporal_reference in @temporal_references
      if temporal_reference.reference == 'MeasurePeriod' and measure_period?
        text += ' and ' if text.length > 0
        text += "#{temporal_reference.offset_text()}#{temporal_reference.type_text()} #{measure_period.name}"
    text
  valueText: =>
    text = ''
    text += if (@value &&
      switch(@value.type)
        when 'PQ' then @value.value
        when 'IVL_PQ' then @value.low && @value.low.value || @value.high && @value.high.value
        when 'CD' then @value.code_list_id
        when 'ANYNonNull' then ': Any Not Null'
    ) then "(result #{@value.text()})" else ""

  fieldsText: =>
    text = ''
    if !$.isEmptyObject(@field_values)
      text += '('
      i=0
      for key in _.keys(this.field_values)
        text+=', ' if i > 0
        i+=1
        field_value = ''
        field_value = @field_values[key].text() if @field_values[key]? && @field_values[key].text?
        text+="#{bonnie.builder.field_map[key].title}:#{field_value}"
      text += ')'
    text

  temporalReferenceItems: =>
    items = []
    if @temporal_references.length > 0
      for temporal_reference in @temporal_references
        if temporal_reference.reference && temporal_reference.reference != 'MeasurePeriod'
          items.push({'conjunction':temporal_reference.type, 'items': [{'id':temporal_reference.reference}], 'negation':null, 'temporal':true, 'title': "#{temporal_reference.offset_text()}#{temporal_reference.type_text()}"})
    if (items.length > 0)
      items
    else
      null

  childrenCriteriaItems: =>
    items = []
    if @children_criteria?.length > 0
      conjunction = 'or'
      conjunction = 'and' if @derivation_operator == 'XPRODUCT'
      for child in @children_criteria
        items.push({'conjunction':conjunction, 'items': [{'id':child}], 'negation':null})
    if (items.length > 0)
      items
    else
      null

  # get the category for the data criteria
  buildCategory: =>
    return 'patient characteristic' if (@type == 'characteristic')
    @definition.replace(/_/g,' ')

class @bonnie.MeasurePeriod
  constructor: (measure_period) ->
    @name = "the measurement period"
    @type = measure_period['type']
    @high = new bonnie.Value(measure_period['high'])
    @low = new bonnie.Value(measure_period['low'])
    @width = new bonnie.Value(measure_period['width'])

class @bonnie.Range
  constructor: (range) ->
    @type = range['type']
    @high = new bonnie.Value(range['high']) if range['high']
    @low = new bonnie.Value(range['low']) if range['low']
    @width = new bonnie.Value(range['width']) if range['width']
  text: (temporal=false)=>
    if (@high? && @low?)
      if (@high.value == @low.value and @high.inclusive and @low.inclusive)
        "#{@low.text(temporal)}"
      else
        ">#{@low.text(temporal)} and <#{@high.text(temporal)}"
    else if (@high?)
      "<#{@high.text(temporal)}"
    else if (@low?)
      ">#{@low.text(temporal)}"
    else
      ''

class @bonnie.AnyNonNull
  constructor: (value) ->
    @type = value['type']

  temporal_unit_text: =>
      ''
  text: (temporal=false) =>
      'Any Value'
  equals: (other) =>
    return other && @type == other.type

class @bonnie.Value
  constructor: (value) ->
    @type = value['type']
    @unit = value['unit']
    @value = value['value']
    @inclusive = value['inclusive?']
    @temporal_unit_decoder = {'a':'year','mo':'month','wk':'week','d':'day','h':'hour','min':'minute','s':'second'}
  temporal_unit_text: =>
    if (@unit?)
      unit = @temporal_unit_decoder[@unit]
      unit += "s " if @value != 1
    else
      ''
  text: (temporal=false) =>
    text = "#{@inclusive_text()} #{@value}"
    if (temporal)
      text += " #{@temporal_unit_text()}"
    else
      text += @unit if @unit?
    text
  inclusive_text: =>
    if (@inclusive? and @inclusive)
      '='
    else
      ''
  equals: (other) =>
    return other && @type == other.type && @value == other.value && @unit == other.unit && @inclusive == other.inclusive

class @bonnie.Coded
  constructor: (value) ->
    @type = value['type']
    @title = value['title'] || ''
    @system = value['system']
    @code = value['code']
    @code_list_id = value['code_list_id']
  text: =>
    if (@title? and @title.length > 0)
      ": #{@title}"
    else
      ": #{@code}"

@bonnie.template = (id, object={}) =>
  $("#bonnie_tmpl_#{id}").tmpl(object)

