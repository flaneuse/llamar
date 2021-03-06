#' Plot food consumption scores by region
#' 
#' In its full version, a plot with four parts: (1) a heatmap breaking down the consumption of food
#' groups by region; (2) a kernel density estimate surface of the food consumption scores (FCS) of
#' individual households in the region; (3) a 1 x n heatmap of the average FCS score by region;
#' and (4) individual mini-maps highlighting the region for context.
#' 
# @import ggplot2 extrafont survey RColorBrewer
# @importFrom gridExtra arrangeGrob
#' 

#' @param df data frame containing the raw, household-level food consumption data. Assumes the individual food group consumption data will be located in separate columns (e.g. legumes, vegetables, etc.)
#' @param region_var string containing the name of the region variable within df
#' @param FCS_var string containing the variable name with calculated FCS
#' @param food_vars list containing the column names containing individual food group consumption
#' 
#' @param na.rm T/F on whether to remove NAs from average
#' @param use_sampleWts whether or not to apply sample weights to the average values by region and for the country
#' @param psu_var string containing the primary sampling unit variable name
#' @param strata_var string containing the strata variable name
#' @param weight_var string containing the weight variable name
#' @param use_FCSWts whether or not to weight each food group by its contribution to FCS
#' @param plot_relativeAvg whether to use relative averages or straight averages in main heatmap
#' 
#' @param poor_FCS cutoff for a 'poor' FCS score
#' @param borderline_FCS cutoff for a 'borderline' FCS score
#' 
#' @param avg_colour colour palette for the main heatmap of the average values of food consumption
#' @param FCS_colour colour palette for the heatmap of avg. FCS by region and distribution
#' @param FCS_range list containing the limist of colors for FCS_colour; default is c(0, 112) -- full range of FCS scores
#' @param alpha_hist alpha (opacity) level for the KDE histogram of the FCS scores
#' 
#' @param admin0 data frame containing lat/long of base of the map. see `frontier::shp2df` for help importing shapefiles.
#' @param region_coords data frame containing lat/long of the regions of interest to map. see `frontier::shp2df` for help importing shapefiles.
#' @param map_base colour to fill the base of the map
#' @param map_accent colour to fill the highlighted region of the map
#' 
#' @param width_indivPlots list contianing the fraction each panel of the plot should occupy
#' 
#' @param filename (optional) filename to save the plots
#' @param width (optional) width of the exported plot
#' @param height (optional) height of the exported plot
#' @param units (optional) units for the width/height of exported plot
#' @param scale (optional) scaling factor for the exported plot
#' 
#' @return p plot grobs for the 3-4 plots together. Can be rendered by calling `gridExtra::grid.arrange(p)`
#' 


fcs_heatmap <- function(df,
                        region_var,
                        map_region_var = region_var,
                        FCS_var = 'FCS',
                        staples_var = 'staples_days', 
                        pulse_var = 'pulse_days', 
                        meat_var = 'meat_days', 
                        milk_var = 'milk_days',
                        veg_var = 'veg_days', 
                        oil_var = 'oil_days', 
                        fruit_var = 'fruit_days', 
                        sugar_var = 'sugar_days',
                        low_FCS_top = TRUE,
                        
                        # -- averaging options --
                        na.rm = FALSE,
                        use_sampleWts = FALSE,
                        psu_var = NA, strata_var = NA, weight_var = NA,
                        use_FCSWts = TRUE,
                        plot_relativeAvg = TRUE,
                        
                        # -- FCS values --
                        poor_FCS = 21,
                        borderline_FCS =  35,
                        
                        # -- colour/aesthetics options --
                        avg_colour = PlBl, # diverging palette
                        FCS_colour = c(brewer.pal(9, 'YlGnBu'), '#081d58', '#081d58', '#081d58', '#081d58'),
                        FCS_range = c(0, 112),
                        alpha_hist = 1,
                        font_light = 'Lato Light',
                        font_normal = 'Lato',
                        label_size = 3,
                        heat_stroke_size = 0.15,
                        
                        # -- histogram options --
                        incl_refHist = FALSE,
                        bw = 'nrd0',
                        
                        # -- map options --
                        plot_map = TRUE,
                        admin0 = NA,
                        region_coords = NA,
                        map_base = grey15K,
                        map_accent = '#d53e4f',
                        
                        # -- plot layout options --
                        width_indivPlots = c(0.1, 0.6, 0.2, 0.1),
                        
                        # -- file saving options --
                        filename = NA,
                        width = NA, 
                        height = NA, 
                        units = 'in', 
                        scale = 1) {
  
  # SETUP: checks and initialize vars --------------------------------------------
  if(plot_map == TRUE) {
    # check that the shapefiles for the maps exist
    if(any(is.na(admin0)) | any(is.na(region_coords))) {
      stop('admin0 or region_coords not specified')
    }
    
    # check that the objects are data frames
    if(is.data.frame(admin0)){
      stop('admin0 is not a dataframe (is it a list?)')
    }
    if(is.data.frame(region_coords)){
      stop('admin0 is not a dataframe (is it a list?)')
    }
    
    # check the mapping data have the right info
    if(!all(c('lat', 'long', 'group', 'order') %in% colnames(admin0))) {
      stop('admin0 is missing geographic columns: lat, long, group, and/or order')
    }
    if(!all(c('lat', 'long', 'group', 'order') %in% colnames(region_coords))) {
      stop('region_coords is missing geographic columns: lat, long, group, and/or order')
    }
    
  }

  # check that the columns exist
  
  if(use_sampleWts == TRUE) {
    # check that sample weighting params are specified
    if(is.na(psu_var) | is.na(weight_var) | is.na(strata_var)){
      stop('parameters to use sample weights are not specified')
    }
  }
  
  # Decide whether to weight main heatmap by their weight in calculating FCS score. 
  # Weights are from the World Food Programme https://www.wfp.org/content/technical-guidance-sheet-food-consumption-analysis-calculation-and-use-food-consumption-score-food-s
  if(use_FCSWts == TRUE){
    staples_weight = 2
    oil_weight =  0.5
    pulse_weight =  3
    sugar_weight =  0.5 
    veg_weight =  1
    milk_weight =  4
    meat_weight = 4 
    fruit_weight =  1 
  } else { # (weight equally)
    staples_weight = 1
    oil_weight =  1
    pulse_weight =  1
    sugar_weight =  1 
    veg_weight =  1
    milk_weight =  1
    meat_weight = 1 
    fruit_weight =  1 
  }
  
  # PART 0: calculate weighted averages for values ------------------------
  if(use_sampleWts == TRUE) {
    FCS_region = llamar::calcPtEst(df, 'FCS', by_var = region_var,
                                   psu_var = 'village', strata_var = 'admin2', weight_var = 'weight')
    
  } else { # (calculate straight averages)
    
    # (a) -- average FCS by region --
    if(na.rm == TRUE) {
      # Exclude missing values
      FCS_region = df %>% 
        filter_(paste0('!is.na(', FCS_var,')')) %>% 
        group_by_(region_var) %>% 
        summarise_(.dots = list(N = 'n()', 
                                FCS_avg = paste0('mean(', FCS_var, ')')))
    } else{
      FCS_region = df %>% 
        group_by_(region_var) %>% 
        summarise_(.dots = list(N = 'n()', 
                                FCS_avg = paste0('mean(', FCS_var, ')')))
    }
    
    # (b) -- average # of days consumed each food, nationally --
    all_avg = df %>% 
      summarise_(staples = paste0('mean(', staples_var, ', na.rm = ', na.rm, ') * ', staples_weight),
                 oils    = paste0('mean(', oil_var,     ', na.rm = ', na.rm, ') * ', oil_weight),
                 pulses  = paste0('mean(', pulse_var,   ', na.rm = ', na.rm, ') * ', pulse_weight),
                 sugar   = paste0('mean(', sugar_var,   ', na.rm = ', na.rm, ') * ', sugar_weight),
                 vegetables = paste0('mean(', veg_var,  ', na.rm = ', na.rm, ') * ', veg_weight),
                 dairy   = paste0('mean(', milk_var,    ', na.rm = ', na.rm, ') * ', milk_weight),
                 meat    = paste0('mean(', meat_var,    ', na.rm = ', na.rm, ') * ', meat_weight),
                 fruits  = paste0('mean(', fruit_var,   ', na.rm = ', na.rm, ') * ', fruit_weight),
                 fcs     = paste0('mean(', FCS_var,     ', na.rm = ', na.rm, ')')) %>% 
      arrange(desc(fcs))
    
    # (c) -- average # of days consumed each food, by region --
    region_avg = df %>% 
      group_by_(regionName = region_var) %>% 
      summarise_(staples = paste0('mean(', staples_var, ', na.rm = ', na.rm, ') * ', staples_weight),
                 oils    = paste0('mean(', oil_var,     ', na.rm = ', na.rm, ') * ', oil_weight),
                 pulses  = paste0('mean(', pulse_var,   ', na.rm = ', na.rm, ') * ', pulse_weight),
                 sugar   = paste0('mean(', sugar_var,   ', na.rm = ', na.rm, ') * ', sugar_weight),
                 vegetables = paste0('mean(', veg_var,  ', na.rm = ', na.rm, ') * ', veg_weight),
                 dairy   = paste0('mean(', milk_var,    ', na.rm = ', na.rm, ') * ', milk_weight),
                 meat    = paste0('mean(', meat_var,    ', na.rm = ', na.rm, ') * ', meat_weight),
                 fruits  = paste0('mean(', fruit_var,   ', na.rm = ', na.rm, ') * ', fruit_weight),
                 fcs     = paste0('mean(', FCS_var,     ', na.rm = ', na.rm, ')')) %>% 
      arrange(desc(fcs))
    
    # (d) -- merge region and average data together and calc diff --
    
    # wide --> long
    all_avg = all_avg %>% 
      gather(food, avg_mean, -fcs) %>%
      rename(fcs_avg = fcs) %>% 
      arrange(desc(avg_mean))
    
    # wide --> long    
    region_avg = region_avg %>% 
      gather(food, region_mean, -regionName, -fcs)
    
    # merge and calc diff
    fcs_heat = full_join(region_avg, all_avg, by = 'food') %>% 
      mutate(diff = region_mean - avg_mean) %>% 
      rowwise() %>% 
      mutate(avg2plot = ifelse(plot_relativeAvg == TRUE, diff, region_mean)) %>% 
      ungroup() %>% 
      arrange(desc(avg_mean))
    
    # (e) -- reorder levels --
    # regions
    if(low_FCS_top == TRUE){
      fcs_heat$regionName = forcats::fct_reorder(fcs_heat$regionName, fcs_heat$fcs, .desc = TRUE)
    }else {
      fcs_heat$regionName = forcats::fct_reorder(fcs_heat$regionName, fcs_heat$fcs)
    }
    
    df[[region_var]] = forcats::fct_relevel(df[[region_var]], rev(levels(fcs_heat$regionName)))
    FCS_region[[region_var]] = forcats::fct_relevel(FCS_region[[region_var]], levels(fcs_heat$regionName))
    
    # food groups
    fcs_heat$food = forcats::fct_reorder(fcs_heat$food, rev(fcs_heat$avg_mean))
  }
  
  # PART 1: individual maps ----------------------------------------------
  
  if(plot_map == TRUE){
    
    # relevel and remove extraneous levels
    region_coords[[map_region_var]] = forcats::fct_relevel(region_coords[[map_region_var]], 
                                                       rev(levels(fcs_heat$regionName)))
    
    region_coords = region_coords %>% 
      filter_(paste0('!is.na(', map_region_var, ')'))
    
    
    # create copy for facetting
    adm0_copy = copy4facet(admin0, unique(fcs_heat$regionName))
    
    
    maps = 
      ggplot(region_coords, aes(x = long, y = lat, group = group, order = order)) + 
      
      # -- base fill the country --
      geom_polygon(fill = map_base, data = adm0_copy) +
      
      
      # -- facet --
      facet_wrap(as.formula(paste0('~', map_region_var)), ncol = 1) +
      
      # -- choropleth over regions --
      geom_polygon(fill = map_accent) +
      
      # -- themes --
      # theme_void() + 
      coord_equal() +
      coord_fixed(ratio  = 1) +
      theme_xylab() +
      ggtitle('FCS, relative to the national average') +
      
      theme_xylab() +
      
      theme(axis.line = element_blank(),
            axis.text.x = element_text(size = 6),
            axis.text.y = element_blank(),
            strip.text = element_blank())
    
  }
  
  
  
  # PART 2: heatmap of food consumption by food group + region ------------
  avg_max = max(max(fcs_heat$avg2plot), abs(min(fcs_heat$avg2plot)))
  
  FCS_heat = 
    ggplot(fcs_heat) +
    geom_tile(aes(x = food, y = regionName, fill = avg2plot), 
              color = 'white', size = heat_stroke_size) +
    scale_fill_gradientn(colours = avg_colour, 
                         limits = c(-1 * avg_max, avg_max)) +
    
    # geom_text(aes(x = food, y = regionName,
    # label = round(avg2plot, 1)), size = 4) +
    
    # -- labels --
    ggtitle('FCS, relative to the national average') +
    
    # -- force plot to have square tiles --
    coord_fixed(ratio = 1) +
    
    # -- themes --
    theme_xylab() +
    
    theme(axis.line = element_blank(),
          axis.text.x = element_text(size = 6))
  
  
  
  # PART 3: distribution of FCS scores by region --------------------------
  df_copy = copy4facet(df %>% select_(FCS_var), 
                       levels(df[[region_var]]))
  
  
  if (incl_refHist == TRUE) {
    FCS_hist = 
      ggplot(df, aes_string(x = FCS_var)) +
      # -- total density distribution --
      geom_density(size = 0.25, colour = grey60K,
                   fill = grey30K,
                   data = df_copy, 
                   alpha = alpha_hist)
  } else { 
    FCS_hist = 
      ggplot(df, aes_string(x = FCS_var)) 
  }
  
  FCS_hist = FCS_hist +
    # -- gradient shading of color -- 
    geom_histogram(aes(x = x, y = 4 *..density.., fill = ..x..),
                   binwidth = 1,
                   data = data.frame(x = seq(from = FCS_range[1], to = FCS_range[2])),
                   alpha = alpha_hist) +
    
    # -- reference lines of poor and borderline FCS scores --
    geom_vline(xintercept = poor_FCS, 
               colour = grey90K, size = 0.1) +
    geom_vline(xintercept = borderline_FCS, 
               colour = grey90K, size = 0.1) +
    
    # -- annotation --
    # annotate('text', x = poor_FCS, y = .05, 
    #          label = 'poor',
    #          hjust = 0.5, family = font_light, 
    #          size = 2, colour = grey60K) +
    ggtitle('poor borderline acceptable diet') +
    
    # -- density distribution (stroke) --
    geom_density(size = 0.25, colour = grey90K) +
    
    # -- density distribution (for clipping) --
    # **! keep as the outer most element for ease of clipping in AI.
    geom_density(fill = 'dodgerblue', size = 0) +
    
    # -- facet --
    facet_wrap(as.formula(paste0('~', region_var)), ncol = 1) +
    
    # -- scales --
    scale_fill_gradientn(colours = FCS_colour) +
    
    # -- themes --
    theme_xylab() +
    
    theme(axis.line = element_line(size = 0.1, colour = grey90K),
          axis.line.y = element_blank(),
          axis.text.y = element_blank(),
          axis.text.x = element_text(size = 6),
          strip.text = element_blank())
  
  
  
  # PART 4: average FCS score by region -----------------------------------
  FCS_avg = 
    ggplot(FCS_region, aes_string(y = region_var, 
                                  x = '1',
                                  fill = 'FCS_avg')) +
    # -- heatmap --
    geom_tile(colour = 'white', size = heat_stroke_size) +
    
    # -- labels --
    geom_text(aes(label = round(FCS_avg, 0)),
              colour = 'white',
              family = font_normal,
              size = label_size) +
    ggtitle('FCS, relative to the national average') +
    
    # -- scales --
    coord_fixed(ratio  = 1) +
    scale_fill_gradientn(colours = FCS_colour, limits = FCS_range) + 
    
    # -- themes --
    theme_xylab() +
    
    theme(axis.line = element_blank(),
          axis.text.x = element_text(size = 6),
          axis.text.y = element_blank())
  
  
  # MERGE, PLOT, and SAVE --------------------------------------------------
  # check widths make sense
  
  if(plot_map == TRUE){
    # note: use arrangeGrob, not arrange.grid, to produce ggsave-able object
    p = gridExtra::arrangeGrob(maps, FCS_heat, FCS_hist, FCS_avg, ncol = 4, widths = width_indivPlots,
                               padding = unit(0, "line"))
  } else {
    p = gridExtra::arrangeGrob(FCS_heat, FCS_hist, FCS_avg, ncol = 3, widths = width_indivPlots)
  }
  
  # -- calls llamar::save_plot to save the plot --
  if (!is.na(filename)){
    save_plot(filename, plot = p, width, height, units, scale)
  }
  
  return(p)
}
