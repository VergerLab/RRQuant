library(shiny)
library(bslib)
library(tidyverse)
library(plotly)
library(sortable)



# User interface: layout description and organisation:
ui <- page_fillable(
  theme = bs_theme(
    fg = "#043927",           
    primary = "#043927",      
    secondary = "#98FB98",     
    font_scale = NULL,         
    preset = "simplex",         
    bg = "#e4e7eb",
    `enable-transitions` = TRUE,
    `enable-shadows` = TRUE,
    font_base = "Arial",
    font_weight_base = "semibold"
  ),
  titlePanel("RRQuant: plot your data"),
  sidebarLayout(
    sidebarPanel(
      style = "background-color: white; width: 350px;",
      fileInput("work_folder", 
                "Choose data file:", 
                multiple = FALSE, 
                accept = c(".csv")),
      uiOutput("select_y"),
      uiOutput("checkbox_ui"),
      uiOutput("rank_x"),
      radioButtons("group_by", 
                   "X axis: group by", 
                   choices = c("Conditions", "Conditions & replicates")),
      actionButton("render_plot", 
                   "Show plot(s)"),
      sliderInput("plotWidth", 
                  "Plot width:", 
                  min = 300,
                  max = 1200,
                  value = 600,
                  step = 20),
      sliderInput("plotHeight",
                  "Plot height:",
                  min = 300,
                  max = 600,
                  value = 400,
                  step = 20),
      downloadButton("save_PDF", 
                     "Save as PDF")
    ),
    mainPanel(
      uiOutput("plots_ui")
    )
  )
)

server <- function(input, output, session) {
  # Reactive expression for reading data
  donnees <- reactive({
    req(input$work_folder)
    file <- input$work_folder$datapath
    read_csv(file)
  })
  
  # Update when donnees() changes so when a new file is browsed.
  output$table <- renderDataTable({
    req(donnees())  
    datatable(donnees())
  })
  
  # Reactive value to store last rendered plots: allows to display several plots
  lastRenderedPlots <- reactiveVal(NULL)
  
  # Reactive expression for UI updates based on the file content (Y axis, conditions..)
  observeEvent(donnees(), {
    output$checkbox_ui <- renderUI({
      checkboxGroupInput("Condition_to_display", 
                         "Conditions:", 
                         choices = unique(donnees()$Condition), 
                         selected = unique(donnees()$Condition))
    })
    
    output$select_y <- renderUI({
      selectInput("data_to_display", 
                  "To plot:", 
                  choices = colnames(donnees())[sapply(donnees(), is.numeric)], 
                  multiple = TRUE,
                  selected = NULL)
            })
  })
  
  output$rank_x <- renderUI({
    req(donnees(), input$Condition_to_display)
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
  
  # control the apparition of the plots by clicking "Show plot(s)" 
  plotData <- eventReactive(input$render_plot, {
    req(donnees(), input$Condition_to_display, input$ranked_x)
    
    filtered_data <- donnees() %>%
      filter(Condition %in% input$Condition_to_display)
    
    # Factor the Condition column based on the ordered rank_list
    filtered_data$Condition <- factor(filtered_data$Condition, levels = input$ranked_x)
    
    # Create a combined factor if grouping by replicate
    if (input$group_by == "Conditions & replicates") {
      filtered_data$Condition_Replicate <- interaction(
        filtered_data$Condition, filtered_data$Replicate, sep = "_", lex.order = TRUE
      )
          } else {
      filtered_data$Condition_Replicate <- filtered_data$Condition
    }
    
    return(filtered_data)
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
  
  # Render plots and store them in the reactive value when the button is clicked
  observeEvent(input$render_plot, {
    plots <- lapply(input$data_to_display, function(var) {
      data_to_plot <- plotData()
      
      ggplot(data_to_plot, aes_string(x = if (input$group_by == "Conditions") "Condition" else "Condition_Replicate", y = var)) +
        geom_jitter(aes(color = Replicate), size = 2, alpha = 1) +
        geom_boxplot(color = 'black', alpha = 0.7, width = 0.7, fill = "#8C979A") +
        stat_summary(fun = "mean", geom = "point", shape = 3, size = 3, fill = "black") +
        labs(title = var) +
        theme(
          panel.background = element_rect(fill = "white"),
          panel.grid.major = element_line(color = "darkgrey"),
          panel.grid.minor = element_line(color = "lightgrey"),
          panel.grid.major.x = element_blank()
        )
      
    })
    
    lastRenderedPlots(plots)
    
    lapply(seq_along(plots), function(i) {
      plot_id <- paste("plot_", input$data_to_display[i], sep = "")
      output[[plot_id]] <- renderPlot({
        print(plots[[i]])
      },  width = reactive({ input$plotWidth }), height = reactive({ input$plotHeight }))
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
      lapply(lastRenderedPlots(), function(plot) {
        print(plot)
      })
      dev.off()
    }
  )
}

shinyApp(ui, server)
