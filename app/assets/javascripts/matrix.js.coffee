bonnie = @bonnie || {}

class @bonnie.Matrix
  constructor: (raw_data) ->
    @raw_data = raw_data
    @headers = []
    @nodes = []
    @row_info = {}
    @column_counts = []
    @data = @build()

  build: () =>
    matrix = []
    @raw_data.forEach((row) =>
      value = row.value
      current_measure = [value.nqf_id, value.sub_id]
      patient_id = value.patient_id
      x = @getHeaderIndex(@headers, current_measure)
      y = @getPatientIndex(@nodes, patient_id)

      @row_info[patient_id] = { first: value.first, last: value.last }

      matrix_column = (matrix[y] || matrix[matrix.push([]) - 1])

      categories = []
      categories.push(5) if (value.DENEXCEP)
      categories.push(4) if (value.DENEX)
      categories.push(3) if (value.NUMER || value.MSRPOPL)
      categories.push(2) if (value.DENOM && value.DENOM > (value.NUMER || 0) && value.DENOM > ((value.DENEXCEP || 0) + (value.DENEX || 0)))
      categories.push(1) if (value.IPP && (value.IPP > ((value.DENOM || 0) + (value.DENEX || 0) + (value.DENEXCEP || 0)+ (value.MSRPOPL || 0))))

      categories.push(0) if (categories.length == 0) 

      categories.sort().reverse()

      @column_counts[x] = @column_counts[x] || {}
      keys = ['IPP', 'DENOM', 'NUMER', 'DENEX', 'DENEXCEP', 'MSRPOPL'];
      for key in keys
        @column_counts[x][key] = (@column_counts[x][key] || 0) + value[key] if value[key]?

      matrix_column[x] = {
        x: x,
        y: y,
        z: 4,
        patient_id: patient_id,
        measure_id: value.measure_id,
        categories: categories,
        category: categories[0]
      })
    matrix

  getHeaderIndex: (headers, current_measure) ->
    x = -1
    for i in [0...headers.length]
      x = i if (!(headers[i] > current_measure) && !(headers[i] < current_measure))
    x = headers.push(current_measure) - 1 if (x == -1)
    x

  getPatientIndex: (nodes, patient_id) ->
    y = nodes.indexOf(patient_id)
    y = nodes.push(patient_id) - 1 if (y == -1)
    y

class @bonnie.MatrixPage
  
  constructor: ->
    @matrix = null
    @colors = ['#eeeeee', '#cccccc', '#40b3bc', '#9cc45e', '#eda039', '#f06560']
    @margin = {top: 135, right: 0, bottom: 0, left: 150}

  init: (data_url) =>
    d3.json(data_url, (data) => 
      @matrix = new bonnie.Matrix(data)
      @display()
    )

    $('#loadingModal').modal({backdrop:'static',keyboard:false});
    $('#toggle_highlight').change(->
      if($(this).prop('checked')) 
        d3.selectAll('.column text').style('fill', -> 
          c = $(this).data('counts')
          if (c['DENOM'] && (c['NUMER'] || c['MSRPOPL']))
          	'' 
          else
           'red'
        )
      else
        d3.selectAll('.column text').style('fill', '');
    )
    $('#toggle_crosshair').change(-> $('#crosshairX, #crosshairY').toggle())

    $('.key_row').click(->
      category = $(this).data('category')
      d3.selectAll('.cell').each((i) ->
        opacity = if (category == 0 || (i.category == category)) then 1 else 0.15
        $(this).css('opacity', opacity)
      )
    )

    $('#loadingModal').modal('hide');

  display: () =>

    # sets the values on the class, things like width hight, x, y, etc
    @setupValues()
    # sets up orders that are used for defining the order of rows and columns
    @setupOrders()

    # build the svg document
    svg = @buildSvg()

    # add the background and crosshairs
    @addBackground(svg)

    # build the rows and columns
    @buildRows(svg)
    @buildColumns(svg)

    # setup data sorters
    @setupSorters(svg, @x, @y, @orders)


  setupValues: () =>
    @row_count = @matrix.data.length

    @width = $('#pageContent').width() - 300 - @margin.left - @margin.right
    @height = @row_count * 15 + @margin.top + @margin.bottom + 100

    @x = d3.scale.ordinal().rangeBands([0, @width])
    @y = d3.scale.ordinal().rangeBands([0, @height])
    @z = d3.scale.linear().domain([0, 4]).clamp(true)
    @c = d3.scale.category10().domain(d3.range(10))

  setupOrders: () =>
    @orders = {
      name: {
        x: d3.range(@matrix.headers.length).sort((a, b) => d3.ascending(@matrix.headers[a][0] + (@matrix.headers[a][1] || ''), @matrix.headers[b][0] + (@matrix.headers[b][1] || ''))),
        y: d3.range(@row_count).sort((a, b) => d3.ascending(@matrix.row_info[@matrix.nodes[a]].last+@matrix.row_info[@matrix.nodes[a]].first, @matrix.row_info[@matrix.nodes[b]].last+@matrix.row_info[@matrix.nodes[b]].first))
      },
      density: {
        x: d3.range(@matrix.headers.length).sort((a, b) => @matrix.data.reduce(((p, e) -> p + (e[b] && e[b].category ? 1 : 0) - (e[a] && e[a].category ? 1: 0)), 0)),
        y: d3.range(@row_count).sort((a, b) => @matrix.data[b].reduce(((p, e) => p + (e.category ? 1 : 0)), 0) - @matrix.data[a].reduce(((p, e) -> p + (e.category ? 1 : 0)), 0))
      }
    };
    @x.domain(@orders.name.x);
    @y.domain(@orders.name.y);

  setupSorters: (svg, x, y, orders) =>
    orderRow = (row) ->
      y.domain(orders[row].y) if (orders[row] && orders[row].y)
      t = svg.transition().duration(2500);
      t.selectAll(".row").delay((d, i) -> y(i) / 2).attr("transform", (d, i) -> "translate(0," + y(i) + ")")

    orderCol = (col) ->
      x.domain(orders[col].x) if (orders[col] && orders[col].x)
      svg.selectAll(".row .cell").attr("x", (d) -> x(d.x))
      svg.selectAll(".column").attr("transform", (d, i) -> "translate(" + x(i) + ")rotate(-90)" )

    d3.select("#orderCol").on("change", -> orderCol(this.value));
    d3.select("#orderRow").on("change", -> orderRow(this.value));

  buildSvg: () =>
    width = @width + @margin.left + @margin.right
    height = @height + @margin.top + @margin.bottom
    svg = d3.select("#pageContent").append("svg")
    svg.attr("width", width).attr("height", height).style("margin-left", 'auto')
    .on('mousemove', (e) =>
      e = d3.event
      offsetX = e.pageX - @margin.left
      offsetY = e.pageY - ($('.background').offset().top)
      offsetX = 0 if offsetX < 0
      offsetY = 0 if offsetY < 0
      $('#crosshairY').css({'top': offsetY})
      $('#crosshairX').css({'left': offsetX})
    ).append("g").attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")

  buildRows: (svg) =>
    # create a row builder closure
    rowBuilder = @setupRowBuilder(@x, @y, @z, @setupGradients(svg), @colors)

    row = svg.selectAll(".row").data(@matrix.data).enter().append("g").attr("class", "row").attr("transform", (d, i) => "translate(0," + @y(i) + ")")
    row.each(rowBuilder)
    
    row.append("line").attr("x2", @width);

    row.append("text").attr("x", -6).attr("y", @x.rangeBand() / 2).attr("dy", ".32em").attr("text-anchor", "end").text((d, i) => 
      @matrix.row_info[@matrix.nodes[i]].last+', '+@matrix.row_info[@matrix.nodes[i]].first)

  setupRowBuilder: (x, y, z, available_gradients, colors) =>

    mouseover = (p) ->
      d3.selectAll(".row text").classed("active", (d, i) -> i == p.y)
      d3.selectAll(".column text").classed("active", (d, i) -> i == p.x)
    mouseout = -> d3.selectAll("text").classed("active", false)

    (row) ->
      cell = d3.select(this).selectAll(".cell")
      .data(row.filter((d) -> d.z))
      .enter().append("rect")
      .attr("class", "cell")
      .attr("x", (d) -> x(d.x))
      .attr("width", x.rangeBand())
      .attr("height", y.rangeBand())
      .style("fill-opacity", (d) -> z(d.z))
      .style("fill", (d) ->
        if (d.categories.length > 1 )
          gradient_key = d.categories.join('_')
          if (available_gradients.indexOf(gradient_key) >= 0)
            return "url(#gradient_"+gradient_key+")"
          else
            return '#000000' 
        else
          return colors[d.category] 
      ) 
      .on("mouseover", mouseover)
      .on("mouseout", mouseout)
      .on('click', (i) -> document.location.href = "/patients/#{i.measure_id}/edit?patient_id=#{i.patient_id}" )

  buildColumns: (svg) =>
    column = svg.selectAll(".column").data(@matrix.headers).enter().append("g").attr("class", "column")
    column.attr("transform", (d, i) => "translate(" + @x(i) + ")rotate(-90)")

    column.append("line").attr("x1", -@width)

    column.append("text").attr("x", 6).attr("y", @x.rangeBand() / 2).attr("dy", ".32em").attr("text-anchor", "start").attr('data-counts', (m, i) => 
      JSON.stringify(@matrix.column_counts[i])
    )
    .text((d, i) => @matrix.headers[i][0] + (@matrix.headers[i][1] || ''))
    .on('click', (i) -> document.location.href = '/measures/' + i[0])

    $('.column text').popover({
      placement: 'left',
      delay: { show: 100, hide: 100 },
      content: () ->
        counts = $(this).data('counts')
        keys = ['IPP', 'DENOM', 'NUMER', 'DENEX', 'DENEXCEP', 'MSRPOPL']
        val = ''
        for key in keys
          val += "#{key}: #{counts[key]} <br />" if counts[key]?
        val
    })

  addBackground: (svg) ->
    svg.append("rect").attr("class", "background").attr("width", @width).attr("height", @height);
    @addCrosshairs()

  addCrosshairs: -> 
    crosshairs = $(document.createElement('div')).addClass('crosshair_container')
    crosshairs.css("width", @width).css("height", @height).css('top', @margin.top).css('left', @margin.left)
    crosshairs.append($(document.createElement('hr')).attr('id', 'crosshairY'), $(document.createElement('hr')).attr('id', 'crosshairX'))
    crosshairs.appendTo('#pageContent')

  setupGradients: (svg) =>
    available_gradients = []
    defs = svg.append('svg:defs')
    colors = @colors

    _.each([[4,1],[5,1],[4,3],[4,2],[5,3],[5,2],[3,2],[3,1]], (item) ->
      available_gradients.push(item[0]+'_'+item[1])
      defs.append('svg:linearGradient')
      .attr('x1', "0%").attr('y1', "0%").attr('x2', "100%").attr('y2', "100%")
      .attr('id', 'gradient_'+item[0]+'_'+item[1]).call((gradient) ->
        gradient.append('svg:stop').attr('offset', '49%').attr('style', 'stop-color:'+colors[item[0]]+';stop-opacity:1');
        gradient.append('svg:stop').attr('offset', '51%').attr('style', 'stop-color:'+colors[item[1]]+';stop-opacity:1');
      )
    )

    _.each([[4,2,1],[5,2,1],[3,2,1],[5,4,3],[5,4,3]], (item) ->
      available_gradients.push(item[0]+'_'+item[1]+'_'+item[2])
      defs.append('svg:linearGradient')
      .attr('x1', "0%").attr('y1', "0%").attr('x2', "100%").attr('y2', "100%")
      .attr('id', 'gradient_'+item[0]+'_'+item[1]+'_'+item[2]).call((gradient) ->
        gradient.append('svg:stop').attr('offset', '38%').attr('style', 'stop-color:'+colors[item[0]]+';start-opacity:1;stop-opacity:1');
        gradient.append('svg:stop').attr('offset', '38%').attr('style', 'stop-color:'+colors[item[1]]+';start-opacity:1;stop-opacity:1');
        gradient.append('svg:stop').attr('offset', '62%').attr('style', 'stop-color:'+colors[item[1]]+';start-opacity:1;stop-opacity:1');
        gradient.append('svg:stop').attr('offset', '62%').attr('style', 'stop-color:'+colors[item[2]]+';start-opacity:1;stop-opacity:1');
      )
    )
    available_gradients

