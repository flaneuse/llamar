#' @export
plot_dot = function(df,
                    by_var = 'region',
                    value_var = 'avg',
                    use_weights = TRUE,
                    
                    sort_desc = TRUE,
                    sort_by = 'diff', # one of: 'diff', 'first', 'last', 'none'
                    
                    reference_line = TRUE,
                    line_stroke = 0.25,
                    line_colour = grey75K,
                    
                    lollipop = FALSE,
                    
                    facet_var = NA,
                    ncol = NULL,
                    nrow = NULL,
                    scales = 'fixed',
                    
                    include_arrows = TRUE,
                    arrow_arg = arrow(length = unit(0.03, "npc")),
                    connector_length = 0.85, # fraction of total difference
                    dot_size = 6, 
                    dot_shape = 21,
                    fill_value = TRUE,
                    dot_fill_discrete = c('#D3DEED', '#3288BD'), # first year, second year tuple
                    dot_fill_cont = brewer.pal(9, 'YlGnBu'),
                    connector_stroke = 0.25,
                    connector_colour = grey75K,
                    
                    label_vals = TRUE,
                    label_size = 3,
                    label_colour = grey75K,
                    label_digits = 1,
                    percent_vals = FALSE,
                    value_label_offset = 0,
                    
                    label_group = TRUE,
                    label_group_size = 4,
                    group_label_offset = 0.25, 
                    
                    horiz = TRUE,
                    
                    file_name = NA,
                    width = 10,
                    height = 6,
                    saveBoth = FALSE,
                    
                    font_normal = 'Lato',
                    font_semi = 'Lato',
                    font_light = 'Lato Light',
                    panel_spacing = 1, # panel spacing, in lines
                    font_axis_label = 12,
                    font_axis_title = font_axis_label * 1.15,
                    font_facet = font_axis_label * 1.15,
                    font_legend_title = font_axis_label, 
                    font_legend_label = font_axis_label * 0.8,
                    font_subtitle = font_axis_label * 1.2,
                    font_title = font_axis_label * 1.3,
                    legend.position = 'none', 
                    legend.direction = 'horizontal',
                    grey_background = FALSE,
                    background_colour = grey10K,
                    projector = FALSE){
  
  # -- calculate the average, by a particular variable --
  # df_avgs = calcPtEst(df, value_var, by_var = by_var, use_weights = use_weights)
  
  # -- calculate the sample mean --
  if (reference_line == TRUE) {
    # avg_val = calcPtEst(df, value_var, use_weights = use_weights)
  }
  
  # -- plot the object --
  p = ggplot(df_avgs, aes_string(x = 'avg', 
                                 y = paste0('forcats::fct_reorder(', by_var, ', avg)'),
                                 fill = 'avg')) +
    # geom_vline(xintercept = reference_line,
               # size = line_stroke,
               # colour = line_colour) +
    # annotate(geom = 'text', x = reference_line * 1.1, y = 1, 
             # colour = label_colour, size = label_size, family = font_light) +
    geom_point(size = dot_size, shape = dot_shape, colour = grey90K, stroke = 0.1) +
    scale_fill_gradientn(colours = dot_fill_cont) +
    theme_xgrid()
  
  # -- add the reference line --
  if(reference_line != FALSE){
    p = p + 
      geom_vline(xintercept = reference_line,
                 size = line_stroke,
                 colour = line_colour) +
      annotate(geom = 'text', x = reference_line * 1.1, y = 1, 
               label = 'sample average', hjust = 0, 
               colour = label_colour, size = label_size, family = font_light)
  }
  
  # -- add in lollipop lines to 0, if TRUE --
  if(lollipop == TRUE) {
    p = p +
      geom_segment(aes_string(x = 'avg', xend = '0', y = by_var, yend = by_var),
                   colour = line_colour, size = line_stroke)
  }
  
  # -- save plot --
  if(!is.na(file_name)) {
    save_plot(file_name, saveBoth = saveBoth, width = width, height = height)
  }
  
  # -- return --
  return(p)
}