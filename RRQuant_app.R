# Libraries needed to run the code:
# For reading csv files and render the application:
library(shiny)
library(bslib)
library(tidyverse)
library(plotly)
library(sortable)
library(agricolae)

file_path <- choose.files(caption = "Select the CSV file", multi = FALSE, filters = c("CSV files" = ".csv"))

# Read the CSV file into 'data' dataframe
data = data.table::fread(file_path) 

# Assuming your original data frame is called 'df'
df_list <- list()

for (col in names(data)[names(data) != "Condition"]) {
  df_temp <- data %>% select(Condition, !!col)
  names(df_temp)[2] <- "value"
  assign(paste0("df_", col), df_temp)
  df_list[[col]] <- df_temp
}

# Columns to remove (non numerical values)
columns_to_remove <- c("Replicate", "Sample", "Condition_replicate")

for (col in columns_to_remove) {
  df_list[[col]] <- NULL
}

df_list <- lapply(df_list, function(df) {
  names(df)[2] <- "value"
  return(df)
})

data_summarized_list <- lapply(df_list, function(df) {
  df %>%
    group_by(Condition) %>%
    summarize(Max.value = max(value)) %>%
    ungroup()
})


# Perform the Honest Significant Difference (HSD) test for multiple comparisons of means
hsd_list <- lapply(df_list, function(df) {
  HSD.test(aov(value ~ Condition, data = df), "Condition", group = TRUE)
})


# Create a list of data frames from the hsd_list
hsd_df_list <- lapply(hsd_list, function(hsd) {
  data.frame(hsd$groups) %>%
    mutate(Condition = row.names(hsd$groups)) %>%
    select(-value)
})

# Join the data frames from df_list and hsd_df_list
stats_list <- Map(function(df, hsd_df) {
  left_join(df, hsd_df, by = "Condition")
}, df_list, hsd_df_list)

for (i in seq_along(data_summarized_list)) {
  condition <- data_summarized_list[[i]]$Condition
  groups <- hsd_df_list[[i]]$groups[match(condition, hsd_df_list[[i]]$Condition)]
  data_summarized_list[[i]]$groups <- groups
}

# Create a new list to store the modified dataframes
combined_list <- lapply(stats_list, function(df) {
  # Add the additional columns
  df$sample <- data$Sample[1:nrow(df)]
  df$cond_replicate <- data$Condition_Replicate[1:nrow(df)]
  df$rep <- data$Replicate[1:nrow(df)]
  
  df
})
# Set the names of the list elements
names(combined_list) <- names(stats_list)



#________________________________________________________________________________________________________________________________________
# User interface: layout description and organisation: __________________________________________________________________________________
#________________________________________________________________________________________________________________________________________

ui <- fluidPage(
  # Java script to define the initial window size on app load
  tags$script(HTML("
    // Set initial window size on app load
    $(document).ready(function() {
      window.resizeTo(1200, 800); // Width: 1200px, Height: 1500px
    });
  ")),
  theme = bs_theme(
    fg = "#11270B",
    primary = "#724e91",
    secondary = "#800020",
    font_scale = NULL,
    preset = "simplex",
    bg = "#fafafa",
    `enable-transitions` = TRUE,
    `enable-shadows` = TRUE,
    font_base = "Arial",
    font_weight_base = "semibold"
  ),
  titlePanel("RRQuant: plot your data"),
  div(class = "mb-4"),
  sidebarLayout(
    sidebarPanel(
      style = "background-color: #e7e6eb; border: 4px solid #4e0110; padding: 15px; border-radius: 3px;",
      width = 5,
      uiOutput("select_y"),
      uiOutput("checkbox_ui"),
      uiOutput("rank_x"),
      radioButtons("group_by",
                   "X axis: group by",
                   choices = c("Boxplot only", "Show jitter plot", "Show jitter plot with replicates")),
      actionButton("render_plot",
                   "Show plot(s)"),
      sliderInput("plotWidth",
                  "Plot width (px):",
                  min = 300,
                  max = 1200,
                  value = 600,
                  step = 20),
      sliderInput("plotHeight",
                  "Plot height (px):",
                  min = 300,
                  max = 600,
                  value = 400,
                  step = 20),
      downloadButton("save_PDF",
                     "Save as PDF")
    ),
    mainPanel(
      tags$style(HTML("
    .nav-tabs .nav-link {
      border: 3px solid #4e0110 !important; /* Thicker border for tabs */
      border-radius: 3px; /* Rounded corners */
      margin-right: 5px; /* Space between tabs */
      padding: 5px 10px; /* Padding inside tabs */
      background-color: #fafafa; /* Background color for tabs */
    }
    .nav-tabs .nav-link.active {
      background-color: #fda50f; /* Background color for active tab */
    }
  ")),
      width = 7,
      tabsetPanel(type = "tabs", id = "tabs",
                  tabPanel("Plot", 
                           style = "background-color: #fafafa",
                           uiOutput("plots_ui")),
                  tabPanel("Interactive", uiOutput("plots_interactive")),
                  
      )
    )
  )
)


server <- function(input, output, session) {
  
  # Reactive value to store last rendered plots: allows to display several plots
  lastRenderedGgplots <- reactiveVal(NULL)
  lastRenderedPlotlys <- reactiveVal(NULL)
  
  #________________________________________________________________________________Choose which data to plot (X)
  filtered_cond <- reactive({
    lapply(combined_list, function(df) {
      df[df$Condition %in% input$Condition_to_display]
    })
  })
  
  output$checkbox_ui <- renderUI({
    checkboxGroupInput("Condition_to_display",
                       "Conditions:",
                       choices = unique(unlist(lapply(combined_list, function(df) df$Condition))),
                       selected = unique(unlist(lapply(combined_list, function(df) df$Condition))))
  })
  
  
  output$rank_x <- renderUI({
    req(input$Condition_to_display)
    selected_Conditions <- input$Condition_to_display
    rank_list(
      text = "X axis order",
      labels = selected_Conditions,
      input_id = "ranked_x",
      options = sortable_options(),
      orientation = c("vertical"),
      class = "default-sortable"
    )
  }) 
  
  #________________________________________________________________________________Choose which data to plot (Y)    
  
  # Create a reactive expression for the selected data frames
  selected_df <- reactive({
    req(input$data_to_display)
    combined_list[input$data_to_display]
    })

  
  selected_stats <- reactive({
    req(input$Condition_to_display)
    lapply(data_summarized_list, function(df) {
      df[df$Condition %in% input$Condition_to_display, ]
    })
  })
  
  # Render the select input
  output$select_y <- renderUI({
    selectInput("data_to_display", 
                "To plot:", 
                choices = names(combined_list), 
                multiple = TRUE,
                selected = NULL)
  })
  
  labels_stats <- eventReactive(input$render_plot, {
    req(input$Condition_to_display)
    # Filter the data based on the selected conditions
    lapply(selected_stats(), function(df) {
      df[df$Condition %in% input$Condition_to_display, ]
    })
  })
  
  #________________________________________________________________________________PLOTS   
  
  # Generate the data based on the user selection and conditions
  plotData <- eventReactive(input$render_plot, {
    req(input$Condition_to_display, input$data_to_display)
    
    # Get the selected data frames from combined_list based on the input selection
    selected_data <- lapply(input$data_to_display, function(var) {
      df <- combined_list[[var]]  # Use the correct dataframe
      # Filter by Condition
      df[df$Condition %in% input$Condition_to_display, ]
    })
    
    # Apply the ranking (ordering the Condition factor)
    lapply(selected_data, function(df) {
      df$Condition <- factor(df$Condition, levels = input$ranked_x)
      df
    })
  })
  
  
  # Generate UI elements for the plots based on selected variables
  output$plots_ui <- renderUI({
    req(input$data_to_display)
    plot_output_list <- lapply(input$data_to_display, function(var) {
      div(
        style = "margin-bottom: 200px;",
        plotOutput(outputId = paste("plot_", var, sep = ""))
      )
    })
    do.call(tagList, plot_output_list)
  })
  
  observeEvent(input$render_plot, {
    plots <- lapply(seq_along(input$data_to_display), function(i) {
      var <- input$data_to_display[[i]]  # Use the correct variable name
      data_to_plot <- plotData()[[i]]  # Get the correct filtered data
      
      
      # Create a combined factor if grouping by replicate
      if (input$group_by == "Show jitter plot") {
        ggplot(data_to_plot, aes(x = Condition, y = value)) +
          geom_boxplot(aes(fill = Condition), alpha = 0.8) +
          geom_text(data = labels_stats()[[var]], aes(x = Condition, y = (0.05 * Max.value) + Max.value, label = groups),
                    vjust = 0) +
          geom_jitter(alpha = 1, size = 1) +
          theme_classic() +
          viridis::scale_fill_viridis(discrete = TRUE) +
          labs(y = var) +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
        
      } else if (input$group_by == "Show jitter plot with replicates") {
        ggplot(data_to_plot, aes(x = Condition, y = value)) +
          geom_boxplot(alpha = 0.8) +
          geom_text(data = labels_stats()[[var]], aes(x = Condition, y = (0.05 * Max.value) + Max.value, label = groups),
                    vjust = 0) +
          geom_jitter(aes(colour = rep, shape = rep), alpha = 1, size = 2) +
          theme_classic() +
          scale_color_viridis_d(option = "inferno", begin = 0.2, end = 0.8) +
          labs(y = var) +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
        
      } else {
        ggplot(data_to_plot, aes(x = Condition, y = value)) +
          geom_boxplot(aes(fill = Condition), alpha = 0.8) +
          geom_text(data = labels_stats()[[var]], aes(x = Condition, y = (0.05 * Max.value) + Max.value, label = groups),
                    vjust = 0) +
          theme_classic() +
          viridis::scale_fill_viridis(discrete = TRUE) +
          labs(y = var) +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      }
    })
    
    lastRenderedGgplots(plots)
    
    lapply(seq_along(plots), function(i) {
      plot_id <- paste("plot_", input$data_to_display[i], sep = "")
      output[[plot_id]] <- renderPlot({
        print(plots[[i]])
      }, width = reactive({ input$plotWidth }), height = reactive({ input$plotHeight }))
    })
  })
  
  
  
  # Download handler for saving plots as PDF
  output$save_PDF <- downloadHandler(
    filename = function() {
      paste("RRplot-", format(Sys.time(), "%Y-%m-%d_%H%M%S"), ".pdf", sep = "")
    },
    content = function(file) {
      pdf(file, width= input$plotWidth / 96, height = input$plotHeight / 96, paper = "special")
      req(input$data_to_display)
      lapply(lastRenderedGgplots(), function(plot) {
        print(plot)
      })
      dev.off()
    }
  )
  
  ##______________________________________________________________________________________________INTERACTIVE TAB  
  
  output$plots_interactive <- renderUI({
    req(input$data_to_display)
    ploti_output_list <- lapply(input$data_to_display, function(var) {
      div(
        style = "margin-bottom: 200px;",
        plotlyOutput(outputId = paste0("ploti_", var, sep = ""))
      )
    })
    
    do.call(tagList, ploti_output_list)
  })
  
  observeEvent(input$render_plot, {
    plotis <- lapply(seq_along(input$data_to_display), function(i) {
      var <- input$data_to_display[[i]]  # Use the correct variable name
      data_to_plot <- plotData()[[i]]  # Get the correct filtered data
      
      # Create a combined factor if grouping by replicate
      pi <- ggplot(data_to_plot, aes(x = Condition, y = value)) +
        geom_boxplot(alpha = 0.8) +
        geom_text(data = labels_stats()[[var]], aes(x = Condition, y = (0.05 * Max.value) + Max.value, label = groups),
                  vjust = 0) +
        geom_jitter(aes(colour = rep, shape = rep, text = paste("Sample:", sample, "<br>Value:", value)), alpha = 1, size = 1) +
        theme_classic() +
        scale_color_viridis_d(option = "inferno", begin = 0.2, end = 0.8) +
        scale_shape_manual(values = c(16, 17, 18, 19, 20, 21)) +
        labs(y = var)+
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
      
      # Convert to plotly plot and enable tooltips to have the label with sample visible
      ggplotly(pi, tooltip = "text")
    })
    
    #Store the generated plots
    lastRenderedPlotlys(plotis)
    
    
    lapply(seq_along(plotis), function(i) {
      ploti_id <- paste0("ploti_", input$data_to_display[i], sep = "")
      output[[ploti_id]] <- renderPlotly({
        plotis[[i]]
      })
    })
  })
}

shinyApp(ui, server)
