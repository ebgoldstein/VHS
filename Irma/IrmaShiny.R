#code to make a Shiny leaflet map for Irma Tweets
#EBG 3/2019 w/ help from EJK
#EBG 10/2019

#https://rstudio.github.io/leaflet/shiny.html

#Install the needed libraries
library(shiny)
library(leaflet)
library(htmlwidgets)
library(sp)
library(tidyverse)
library(mapview)
library(shiny)
library(RColorBrewer)


#import the IRMA tweets (n.b., after the hydration step)
Irma_Tweets <- read_csv("DATA/Irma_Tweets_Coast.csv")

#jitter coordinates for IRMA tweets to avoid overlap (can click on overlapping tweets if zoomed in enough)
#Irma_Tweets[3:4] <- jitter(Irma_Tweets[3:4], factor = 0.001)

#scale text scores from 0 to 1
Irma_Tweets$textScore <- (Irma_Tweets$textScore- min(Irma_Tweets$textScore))/(max(Irma_Tweets$textScore)-min(Irma_Tweets$textScore))

#order by image score so higher scores are on top
Irma_Tweets <- Irma_Tweets[order(Irma_Tweets$imageScore),]

#load Irma tracks
IrmaTrack <- read_csv("DATA/IrmaTrack.csv")
IrmaTrack$datetime <-parse_datetime(IrmaTrack$datetime,"%Y%m%d")
#remove the letters
IrmaTrack$lat <- gsub('.{1}$', '', IrmaTrack$lat)
IrmaTrack$log <- gsub('.{1}$', '', IrmaTrack$log)
#as.numeric
IrmaTrack$lat <- as.numeric(IrmaTrack$lat)
IrmaTrack$log <- as.numeric(IrmaTrack$log)


#URL field for each tweet
URL  = paste0("'","<a"," href", "=", Irma_Tweets$image_url , " target = '_blank'", ">", "TWEET</a>","'") #create hyperlinks from tweets


pal <-   colorNumeric("YlOrRd", c(0,1))

########################################
#build the Shiny UI with 4 sliders, color input, and legend check box: 
# S1) Image Score
# S2) Text Score
# S3) User Score
# S4) Distance to Coastline
ui <- bootstrapPage(
  tags$style(type = "text/css", "html, body {width:100%;height:100%} img {display:block;margin-left:auto;margin-right:auto;width:80%;}"),
  leafletOutput("map", width = "100%", height = "100%"),
  absolutePanel(top = 120, left = 10,
                sliderInput("range", "Image Score", 0,1,
                            value = range(Irma_Tweets$imageScore), step = 0.1),
                sliderInput("rangetwo", "Text Score", 0,1,
                            value = range(Irma_Tweets$textScore), step = 0.1),
                sliderInput("rangethree", "User Score", 0,1,
                            value = range(Irma_Tweets$userScore), step = 0.1),
                sliderInput("rangefour", "Distance to Coastline", 0,100000,
                            value = range(Irma_Tweets$distance), step = 100),
                checkboxInput("legend", "Show legend", TRUE)
  )
)
#########################

server <- function(input, output, session) {
  
  # These are the 4 reactive expressions for the sliders
  filteredData <- reactive({
    Irma_Tweets[Irma_Tweets$imageScore >= input$range[1] & Irma_Tweets$imageScore <= input$range[2] &
                  Irma_Tweets$textScore >= input$rangetwo[1] & Irma_Tweets$textScore <= input$rangetwo[2] & 
                  Irma_Tweets$userScore >= input$rangethree[1] & Irma_Tweets$userScore <= input$rangethree[2] & 
                  Irma_Tweets$distance >= input$rangefour[1] & Irma_Tweets$distance <= input$rangefour[2]
                ,]
  })
  
  
  output$map <- renderLeaflet({
    # Make the leaflet map. Pull the basemap. Changed to Stamen TonerLite for simplicity, but I wish it had color :( -JK 
    leaflet(Irma_Tweets) %>% 
      addProviderTiles(providers$Stamen.TonerLite) %>%
      fitBounds(~min(longitude), ~min(latitude), ~max(longitude), ~max(latitude)) %>% 
      addPolylines(data = IrmaTrack, lng = ~c(-log), lat = ~lat)
  })
  
  # observer for sliders:
  observe({
    leafletProxy("map", data = filteredData()) %>%
      clearMarkers() %>%
      addCircleMarkers(
        ~longitude, 
        ~latitude, 
        stroke = FALSE, radius = 7, 
        fillColor = ~pal(imageScore), 
        fillOpacity = 0.6,
        popup = ~paste("<b>Tweet Text: </b>",text, "<br><br><img width ='80%' src = ", image_url, " alt = 'Tweet Image' align = 'middle'>")
      )
  })
  
  #Observer for legend:
  observe({
    proxy <- leafletProxy("map", data = Irma_Tweets)
    # Remove any existing legend, and only if the legend is
    # enabled, create a new one.
    proxy %>% clearControls()
    if (input$legend) {
      #pal <- colorpal()
      proxy %>% addLegend(position = "bottomright",
                          pal = pal, values = ~imageScore
      )
    }
  })
}

#Make it real:
shinyApp(ui, server)


