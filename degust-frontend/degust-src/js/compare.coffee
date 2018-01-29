
g_vue_obj = null

html_escape = (str) ->
    $('<div/>').text(str).html()


blue_to_brown = d3.scale.linear()
  .domain([0,0.05,1])
  .range(['brown', "steelblue", "steelblue"])
  .interpolate(d3.interpolateLab)

colour_cat20 = d3.scale.category20().domain([1..20])
colour_by_ec = (ec_col) ->
    (row) -> colour_cat20(row[ec_col])

colour_by_pval = (col) ->
    (d) -> blue_to_brown(d[col])

# Globals for widgets
parcoords = null
ma_plot = null
volcano_plot = null
pca_plot = null
gene_expr = null

kegg = null
heatmap = null

g_data = null
requested_kegg = false


# Globals for settings
sortAbsLogFC = true

kegg_filter = []
h_runfilters = null
g_tour_setup = false
g_colour_by_parent = d3.scale.category10()

kegg_mouseover = (obj) ->
    ec = obj.id
    rows = []
    ec_col = g_data.column_by_type('ec')
    return if ec_col==null
    for row in g_data.get_data()
        rows.push(row) if row[ec_col.idx] == ec
    g_vue_obj.current_plot.highlight(rows)

# highlight parallel coords (and/or kegg)
gene_table_mouseover = (item) ->
    g_vue_obj.current_plot.highlight([item])
    ec_col = g_data.column_by_type('ec')
    if ec_col?
        kegg.highlight(item[ec_col.idx])
    heatmap.highlight([item])
    gene_expr.select(g_data, [item])

gene_table_mouseout = () ->
    g_vue_obj.current_plot.unhighlight()
    $('#gene-info').html('')
    kegg.unhighlight()
    heatmap.unhighlight()

calc_max_parcoords_width = () ->
    w = $('.container').width()
    w -= $('.conditions').outerWidth(true) if $('.conditions').is(':visible')
    w -= $('div.filter').outerWidth(true) if $('div.filter').is(':visible')

init_gene_table_menu = () ->
    menu = [
            title: () -> "<input type='checkbox' style='margin-right:10px;' #{if sortAbsLogFC then "checked" else ""}/><label>Sorting by ABSOLUTE logFC</label>"
            action: () =>
                sortAbsLogFC = !sortAbsLogFC
                gene_table.resort()
    ]
    # Popup on right-click
    d3.select('#grid').on('contextmenu', d3.contextMenu(menu))

    # Also, Click on settings icon to popup menu
    d3.select('.gene-table-settings').on('click', (e) ->
        d3.event.preventDefault()
        # Move the popup to the left
        opts = {onPostOpen: (m) -> console.log("move!"); m.style('left', (d3.event.pageX - 250) + 'px')}
        d3.contextMenu(menu,opts)()
    )

init_charts = () ->
    # init_gene_table_menu()

    parcoords = new ParCoords(
        elem: '#dge-pc'
        width: calc_max_parcoords_width()
        filter: expr_filter
        )

    ma_plot = new MAPlot(
        elem: '#dge-ma'
        filter: expr_filter
        xaxis_loc: 'zero'
        brush_enable: true
        canvas: true
        height: 300
        width: 600
        )
    ma_plot.on("mouseover.main", (rows) -> heatmap.highlight(rows); gene_expr.select(g_data, rows))
    ma_plot.on("mouseout.main", () -> heatmap.unhighlight())

    volcano_plot = new VolcanoPlot(
        elem: '#dge-volcano'
        filter: expr_filter
        yaxis_loc: 'zero'
        brush_enable: true
        canvas: true
        height: 300
        width: 600
        )
    volcano_plot.on("mouseover.main", (rows) -> heatmap.highlight(rows); gene_expr.select(g_data, rows))
    volcano_plot.on("mouseout.main", () -> heatmap.unhighlight())

    pca_plot = new GenePCA(
        elem: '#dge-pca'
        filter: expr_filter
        colour: g_colour_by_parent
        sel_dimension: (d) => g_vue_obj.pcaDimension = +d
        params: () ->
            skip: +g_vue_obj.skipGenesThreshold
            num: +g_vue_obj.numGenesThreshold
            dims: [+g_vue_obj.pcaDimension, +g_vue_obj.pcaDimension+1, +g_vue_obj.pcaDimension+2]
            plot_2d3d: g_vue_obj.mds_2d3d
        )
    pca_plot.on("top_genes", (top) =>
        gene_table.set_data(top)
        heatmap.schedule_update(top)
    )

    kegg = new Kegg(
        elem: 'div#kegg-image'
        mouseover: kegg_mouseover
        mouseout: () -> g_vue_obj.current_plot.unhighlight()
        )

    # update grid on brush
    parcoords.on("brush", (d) ->
        gene_table.set_data(d)
        heatmap.schedule_update(d)
    )
    ma_plot.on("brush", (d) ->
        gene_table.set_data(d)
        heatmap.schedule_update(d)
    )
    volcano_plot.on("brush", (d) ->
        gene_table.set_data(d)
        heatmap.schedule_update(d)
    )

    # Used to reorder the heatmap columns by the parcoords order
    order_columns_by_parent = (columns, parent) ->
        pos = {}
        for i in [0...parent.length]
            pos[parent[i]] = i
        new_cols = columns.slice()
        new_cols.sort((a,b) ->
            if pos[a.parent]==pos[b.parent]
                0
            else if pos[a.parent] < pos[b.parent]
                -1
            else
                1
        )
        new_cols

    parcoords.on("render", () ->
        return if !heatmap.columns
        dim_names = parcoords.dimension_names()
        names = parcoords.dimensions().map((c) -> dim_names[c])
        new_cols = order_columns_by_parent(heatmap.columns, names)
        heatmap.reorder_columns(new_cols)
    )

    #Heatmap
    heatmap = new Heatmap(
        elem: '#heatmap'
        show_elem: '.show-heatmap'
    )
    heatmap.on("mouseover", (d) ->
        g_vue_obj.current_plot.highlight([d])
        msg = ""
        for col in g_data.columns_by_type(['info'])
          msg += "<span class='lbl'>#{col.name}: </span><span>#{d[col.idx]}</span>"
        $('#heatmap-info').html(msg)
        gene_expr.select(g_data, [d])
    )
    heatmap.on("mouseout", (d) ->
        g_vue_obj.current_plot.unhighlight()
        $('#heatmap-info').html("")
    )
    heatmap.on("need_update", () -> update_data())

    gene_expr = new GeneExpression(
        elem: '.single-gene-expr'
        width: 233
        colour: g_colour_by_parent
    )

# Filter to decide which rows to plot on the parallel coordinates widget
expr_filter = (row) ->
    if g_vue_obj.fcThreshold>0
        # Filter using largest FC between any pair of samples
        fc = g_data.columns_by_type('fc').map((c) -> row[c.idx])
        extent_fc = d3.extent(fc.concat([0]))
        if Math.abs(extent_fc[0] - extent_fc[1]) < g_vue_obj.fcThreshold
            return false

    # Filter by FDR
    pval_col = g_data.columns_by_type('fdr')[0]
    return false if row[pval_col.idx] > g_vue_obj.fdrThreshold

    # If a Kegg pathway is selected, filter to that.
    if kegg_filter.length>0
        ec_col = g_data.column_by_type('ec')
        return row[ec_col.idx] in kegg_filter

    true


init_genesets = () ->
    $('.geneset-save').on('click', () ->
        console.log "SAVE"
    )
    $('.geneset-search input.search').autocomplete(
        source: "/gene-sets"
        minLength: 2
        select: ( event, ui ) ->
            if ui.item
                d3.json("/gene-sets/#{ui.item.id}", (err, json) ->
                    console.log "JSON", ui, json
                )
    );

calc_kegg_colours = () ->
    ec_dirs = {}
    ec_col = g_data.column_by_type('ec')
    return if ec_col==null
    fc_cols = g_data.columns_by_type('fc_calc')[1..]
    for row in g_data.get_data()
        ec = row[ec_col.idx]
        continue if !ec
        for col in fc_cols
            v = row[col.idx]
            dir = if v>0.1 then "up" else if v<-0.1 then "down" else "same"
            ec_dirs[ec]=dir if !ec_dirs[ec]
            ec_dirs[ec]='mixed' if ec_dirs[ec]!=dir
    return ec_dirs

kegg_selected = () ->
    code = $('select#kegg option:selected').val()
    title = $('select#kegg option:selected').text()

    set_filter = (ec) ->
        kegg_filter = ec
        update_data()

    if !code
        set_filter([])
    else
        ec_colours = calc_kegg_colours()
        kegg.load(code, ec_colours, set_filter)
        $('div#kegg-image').dialog({width:500, height:600, title: title, position: {my: "right top", at:"right top+60", of: $('body')} })

process_kegg_data = (ec_data) ->
    return if requested_kegg
    requested_kegg = true
    opts = "<option value=''>--- No pathway selected ---</option>"

    have_ec = {}
    ec_col = g_data.column_by_type('ec')
    for row in g_data.get_data()
        have_ec[row[ec_col.idx]]=1

    ec_data.sort((a,b) ->
        a=a.title.toLowerCase()
        b=b.title.toLowerCase()
        if a==b then 0 else if a<b then -1 else 1
    )
    ec_data.forEach (row) ->
        num=0
        for ec in row.ec.split(" ").filter((s) -> s.length>0)
            num++ if have_ec[ec]
        if num>0
            opts += "<option value='#{row.code}'>#{row.title} (#{num})</option>"
    $('select#kegg').html(opts)
    $('.kegg-filter').show()

process_dge_data = (data, columns) ->
    g_data = new GeneData(data, columns)

    # Setup FC "relative" pulldown
    # opts = ""
    # for col,i in g_data.columns_by_type(['fc','primary'])
    #     opts += "<option value='#{i}'>#{html_escape col.name}</option>"
    # opts += "<option value='-1'>Average</option>"
    # $('select#fc-relative').html(opts)

    # Setup MA-plot pulldown
    # opts = ""
    # for col,i in g_data.columns_by_type(['fc','primary'])
    #     opts += "<option value='#{i}' #{if i==1 then 'selected' else ''}>#{html_escape col.name}</option>"
    # $('select#ma-fc-col').html(opts)

    if g_data.column_by_type('ec') == null
        $('.kegg-filter').hide()
    else if !requested_kegg
        g_backend.request_kegg_data(process_kegg_data)

    if g_data.columns_by_type('count').length == 0
        $('.show-counts-opt').hide()
        $('#select-pca').hide()
    else
        $('.show-counts-opt').show()
        $('#select-pca').show()

    update_from_link(true)

    # First time throught?  Setup the tutorial tour
    if !g_tour_setup
        g_tour_setup = true
        setup_tour(if settings.show_tour? then settings.show_tour else true)

# Called whenever the data is changed, or the "checkboxes" are modified
update_data = () ->
    # Set the 'relative' column
    fc_relative = $('select#fc-relative option:selected').val()
    if fc_relative<0
        fc_relative = 'avg'
    else
        fc_relative = g_data.columns_by_type(['fc','primary'])[fc_relative]
    g_data.set_relative(fc_relative)

    dims = g_data.columns_by_type('fc_calc')
    pval_col = g_data.column_by_type('fdr')

    if g_vue_obj.current_plot == parcoords
        extent = ParCoords.calc_extent(g_data.get_data(), dims)
        parcoords.update_data(g_data.get_data(), dims, extent, colour_by_pval(pval_col.idx))
    else if g_vue_obj.current_plot == ma_plot
        ma_fc = $('select#ma-fc-col option:selected').val()
        ma_fc = g_data.columns_by_type(['fc','primary'])[ma_fc].name
        fc_col = g_data.columns_by_type('fc_calc').filter((c) -> c.name == ma_fc)[0]
        ma_plot.update_data(g_data.get_data(),
                            g_data.columns_by_type('avg')[0],
                            fc_col,
                            colour_by_pval(pval_col.idx),
                            g_data.columns_by_type('info'),
                            pval_col
                            )
    else if g_vue_obj.current_plot == volcano_plot
        ma_fc = $('select#ma-fc-col option:selected').val()
        ma_fc = g_data.columns_by_type(['fc','primary'])[ma_fc].name
        fc_col = g_data.columns_by_type('fc_calc').filter((c) -> c.name == ma_fc)[0]
        volcano_plot.update_data(g_data.get_data(),
                            fc_col,
                            pval_col,
                            colour_by_pval(pval_col.idx),
                            g_data.columns_by_type('info'),
                            )
    else if g_vue_obj.current_plot == pca_plot
        cols = g_data.columns_by_type('fc_calc').map((c) -> c.name)
        count_cols = g_data.columns_by_type('count').filter((c) -> cols.indexOf(c.parent)>=0)
        pca_plot.update_data(g_data, count_cols)

    set_gene_table(g_data.get_data())

    # Update the heatmap
    if heatmap.enabled()
        if (!heatmap.show_replicates)
            heatmap_dims = g_data.columns_by_type('fc_calc_avg')
            centre=true
        else
            count_cols = dims.map((c) -> g_data.assoc_column_by_type('count',c.name))
            count_cols = [].concat.apply([], count_cols)
            heatmap_dims = Normalize.normalize(g_data, count_cols)
            centre=true
        heatmap.update_columns(g_data, heatmap_dims, centre)

    # Ensure the brush callbacks are called (updates heatmap & table)
    g_vue_obj.current_plot.brush()

init_page = () ->
    setup_nav_bar()
    $('[title]').tooltip()

    if full_settings?
        if full_settings['extra_menu_html']
            $('#right-navbar-collapse').append(full_settings['extra_menu_html'])

    $("select#kegg").change(kegg_selected)

    #$(window).bind( 'hashchange', update_from_link )


sliderText = require('./slider.vue').default
conditions = require('./conditions-selector.vue').default
about = require('./about.vue').default
Modal = require('modal-vue').default
geneTable = require('./gene-table.vue').default
maPlot = require('./ma-plot.vue').default
volcanoPlot = require('./volcano-plot.vue').default
mdsPlot = require('./mds-plot.vue').default
qcPlots = require('./qc-plots.vue').default
geneStripchart = require('./gene-stripchart.vue').default
parallelCoord = require('./parcoords.vue').default
heatmap = require('./heatmap.vue').default
{ Normalize } = require('./normalize.coffee')
{ GeneData } = require('./gene_data.coffee')

backends = require('./backend.coffee')

module.exports =
    name: 'compare'
    components:
        sliderText: sliderText
        conditionsSelector: conditions
        about: about
        Modal: Modal
        geneTable: geneTable
        maPlot: maPlot
        volcanoPlot: volcanoPlot
        mdsPlot: mdsPlot
        qcPlots: qcPlots
        geneStripchart: geneStripchart
        parallelCoord: parallelCoord
        heatmap: heatmap
    data: () ->
        settings: {}
        full_settings: {}
        load_failed: false
        load_success: false
        num_loading: 0
        showCounts: 'no'
        fdrThreshold: 1
        fcThreshold: 0
        fc_relative_i: null
        ma_plot_fc_col_i: null
        fcStepValues:
            Number(x.toFixed(2)) for x in [0..5] by 0.01
        numGenesThreshold: 100
        skipGenesThreshold: 0
        mdsDimension: 1
        maxGenes: 0
        mds_2d3d: '2d'
        r_code: ''
        show_about: false
        dge_method: null
        sel_conditions: []
        cur_plot: null
        cur_opts: 'options'
        gene_data: new GeneData([],[])
        genes_selected: []              # Selected by "brushing" on one of the plots
        genes_highlight: []             # Gene hover from 'mouseover' of table
        genes_hover: []                 # Genes hover from 'mouseover' of plot
        show_heatmap: true
        heatmap_show_replicates: false
        show_qc: ''
        #colour_by_condition: null  # Don't want to track changes to this!

    computed:
        code: () -> get_url_vars()["code"]
        asset_base: () -> this.settings?.asset_base || ''
        home_link: () -> this.settings?.home_link || '/'
        fdrWarning: () -> this.cur_plot == 'mds' && this.fdrThreshold<1
        fcWarning: () -> this.cur_plot == 'mds' && this.fcThreshold>0
        experimentName: () -> this.settings?.name || "Unnamed"
        can_configure: () ->
            !this.settings.config_locked || this.full_settings.is_owner
        config_url: () -> "config.html?code=#{this.code}"
        gene_data_rows: () ->
            this.gene_data.get_data()
        expr_data: () ->
            console.log "computing expr_data.  orig length=", this.gene_data.get_data().length
            Vue.noTrack(this.gene_data.get_data().filter((v) => this.expr_filter(v)))
        avg_column: () ->
            this.gene_data.columns_by_type('avg')[0]
        fdr_column: () ->
            this.gene_data.columns_by_type('fdr')[0]
        fc_relative: () ->
            if this.fc_relative_i>=0
                this.fc_columns[this.fc_relative_i]
            else
                'avg'
        ma_plot_fc_col: () ->
            this.fc_calc_columns[this.ma_plot_fc_col_i]
        fc_columns: () ->
            this.gene_data.columns_by_type(['fc','primary'])
        fc_calc_columns: () ->
            this.fc_relative     # Listed so to create a dependency.
            this.gene_data.columns_by_type(['fc_calc'])
        info_columns: () ->
            this.gene_data.columns_by_type(['info'])
        count_columns: () ->
            this.gene_data.columns_by_type('count')
        filter_changed: () ->
            this.fdrThreshold
            this.fcThreshold
            Date.now()
        heatmap_dimensions: () ->
            if (!this.heatmap_show_replicates)
                heatmap_dims = this.gene_data.columns_by_type('fc_calc_avg')
            else
                count_cols = this.fc_calc_columns.map((c) => this.gene_data.assoc_column_by_type('count',c.name))
                count_cols = [].concat.apply([], count_cols)
                heatmap_dims = Normalize.normalize(this.gene_data, count_cols)
            heatmap_dims

    watch:
        '$route': (n,o) ->
            this.parse_url_params(n.query)
        settings: () ->
            this.dge_method = this.settings.dge_method || 'voom'
            this.sel_conditions = this.$route.query.sel_conditions || this.settings.init_select || []
        cur_plot: () ->
            # On plot change, reset brushes
            this.genes_highlight = []
            this.genes_selected = this.gene_data.get_data()
        maxGenes: (val) ->
            this.$refs.num_genes.set_max(this.numGenesThreshold, 1, val, true)
            this.$refs.skip_genes.set_max(this.skipGenesThreshold, 0, val, true)
        fc_relative: () ->
            this.gene_data.set_relative(this.fc_relative)
        experimentName: () ->
            document.title = this.experimentName

    methods:
        init: () ->
            if !this.code?
                this.load_success=true
                this.$nextTick(() -> this.initBackend(false))
            else
                $.ajax({
                    type: "GET",
                    url: backends.BackendCommon.script(this.code,"settings"),
                    dataType: 'json'
                }).done((json) =>
                    window.full_settings = json
                    window.settings = json.settings
                    this.full_settings = json
                    this.settings = json.settings
                    this.load_success=true
                    this.$nextTick(() -> this.initBackend(true))
                 ).fail((x) =>
                    log_error "Failed to get settings!",x
                    this.load_failed = true
                    this.$nextTick(() ->
                        pre = $("<pre></pre>")
                        pre.text("Error failed to get settings : #{x.responseText}")
                        $('.error-msg').append(pre)
                    )
                )
        initBackend: (use_backend) ->
            this.ev_backend = new Vue()
            this.ev_backend.$on("start_loading", () => this.num_loading+=1)
            this.ev_backend.$on("done_loading", () => this.num_loading-=1)
            this.ev_backend.$on("dge_data", (data,cols) => this.process_dge_data(data,cols))

            if !use_backend
                this.backend = new backends.BackendNone(this.settings, this.ev_backend)
            else
                if this.settings.analyze_server_side
                    this.backend = new backends.BackendRNACounts(this.code, this.settings, this.ev_backend)
                else
                    this.backend = new backends.BackendPreAnalysed(this.code, this.settings, this.ev_backend)
                # If we're not configured, redirect to the config page
                if !this.backend.is_configured()
                    window.location = this.config_url

            init_page()  # TODO - move this
            this.request_data()

        # Send a request to the backend.  First request, or when selected samples has changed
        request_data: () ->
            this.backend.request_data(this.dge_method, this.sel_conditions)

        process_dge_data: (data, cols) ->
            this.gene_data = new GeneData(data, cols)
            this.maxGenes = this.gene_data.get_data().length
            this.fc_relative_i = 0
            this.ma_plot_fc_col_i = 1
            this.set_genes_selected(this.gene_data.get_data())
            this.genes_highlight = []
            this.colour_by_condition = if this.fc_columns.length<=10 then d3.scale.category10() else d3.scale.category20()
            if (!this.cur_plot? || this.cur_plot in ["parcoords","ma"])
                this.cur_plot = if this.fc_columns.length>2 then "parcoords" else "ma"
            if this.fc_columns.length==2
                this.heatmap_show_replicates = true


        # Selected samples have changed, request a new dge
        change_samples: (cur) ->
            this.dge_method = cur.dge_method
            this.sel_conditions = cur.sel_conditions
            this.request_data()

        set_genes_selected: (d) ->
            this.genes_selected = Vue.noTrack(d)

        heatmap_hover: (d) ->
            this.genes_hover = this.genes_highlight = Vue.noTrack([d])
        heatmap_nohover: () ->
            this.genes_highlight=[]
        gene_table_hover: (d) ->
            this.genes_hover = this.genes_highlight = Vue.noTrack([d])
        gene_table_nohover: () ->
            this.genes_highlight=[]

        # Update the URL with the current page state
        update_url_link: () ->
            state = {}
            state.sel_conditions = this.sel_conditions
            state.plot = this.cur_plot
            state.show_counts = this.showCounts
            state.fdrThreshold = this.fdrThreshold
            state.fcThreshold = this.fcThreshold
            #state.sortAbsLogFC = def(sortAbsLogFC, true)
            state.fc_relative_i = this.fc_relative_i
            state.heatmap_show_replicates = this.heatmap_show_replicates
            if this.cur_plot=='mds'
                state.numGenesThreshold = this.numGenesThreshold
                state.skipGenesThreshold = this.skipGenesThreshold
                state.pcaDimension = this.pcaDimension
            #state.searchStr = this.searchStr
            if this.cur_opts=='gene'
                state.single_gene_expr = true
            this.$router.push({name: 'home', query: state})

        parse_url_params: (q) ->
            this.cur_plot = q.plot if q.plot?
            this.showCounts = q.show_counts if q.show_counts?
            if q.fdrThreshold?
                this.fdrThreshold = q.fdrThreshold
            else if settings.fdrThreshold?
                this.fdrThreshold = settings.fdrThreshold
            if q.fcThreshold?
                this.fcThreshold = q.fcThreshold
            else if settings.fcThreshold?
                this.fcThreshold = settings.fcThreshold
            #state.sortAbsLogFC = def(sortAbsLogFC, true)
            this.fc_relative_i = q.fc_relative_i if q.fc_relative_i
            this.heatmap_show_replicates = q.heatmap_show_replicates=='true' if q.heatmap_show_replicates?
            this.numGenesThreshold = q.numGenesThreshold if q.numGenesThreshold?
            this.skipGenesThreshold = q.skipGenesThreshold if q.skipGenesThreshold?
            this.pcaDimension = q.pcaDimension if q.pcaDimension?
            #this.searchStr = q.searchStr if q.searchStr?
            this.cur_opts='gene' if q.single_gene_expr

        # Request and display r-code for current selection
        show_r_code: () ->
            p = this.backend.request_r_code(this.dge_method, this.sel_conditions)
            p.then((d) =>
                this.r_code = d
            )
        close_r_code: () -> this.r_code = ''

        plot_colouring: (d) ->
            blue_to_brown(d[this.fdr_column.idx])
        condition_colouring: (c) ->
            this.colour_by_condition(c)
        fmtPCAText: (v) ->
            v+" vs "+(v+1)
        fdrValidator: (v) ->
            n = Number(v)
            !(isNaN(n) || n<0 || n>1)
        intValidator: (v) ->
             n = Number(v)
             !(isNaN(n) || n<0)

        # Check if the passed row passes filters for : FDR, FC, Kegg
        expr_filter: (row) ->
            #console.log "filter"
            if this.fcThreshold>0
                # Filter using largest FC between any pair of samples
                fc = this.gene_data.columns_by_type('fc').map((c) -> row[c.idx])
                extent_fc = d3.extent(fc.concat([0]))
                if Math.abs(extent_fc[0] - extent_fc[1]) < this.fcThreshold
                    return false

            # Filter by FDR
            pval_col = this.fdr_column
            return false if row[pval_col.idx] > this.fdrThreshold

            # If a Kegg pathway is selected, filter to that.
            if kegg_filter.length>0
                ec_col = this.gene_data.column_by_type('ec')
                return row[ec_col.idx] in kegg_filter

            true

    mounted: () ->
        g_vue_obj = this
        this.init()
        this.parse_url_params(this.$route.query)

        # TODO : ideally just this component, not window.  But, need ResizeObserver to do this nicely
        window.addEventListener('resize', () => this.$emit('resize'))
