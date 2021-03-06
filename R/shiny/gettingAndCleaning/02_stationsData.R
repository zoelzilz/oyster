############### create helper functions for getting data #######################
# railway stations data from wikipedia -----------------------------------------
GetRailStations <-
  function(url = "http://en.wikipedia.org/wiki/List_of_London_railway_stations") {
    # function that loads a URL and extracts the first table from the page
    # by default it will operate on the Wikipedia list of london railway
    # stations page. The first table contains the location data for each station
  url %>%
  html() %>%
  html_nodes("table") %>%
  .[[1]] %>%
  html_table %>%
  tbl_df()
}

# tube stations from wikipedia -------------------------------------------------
# starting with Baker street, get the links to the other stations
ExtractLinks <-
function(url = "http://en.wikipedia.org/wiki/Baker_Street_tube_station") {
  # takes a URL and extracts all links from it
  url %>%
    html() %>%
    html_nodes("a") %>%
    html_attr("href") %>%
    grep("wiki", ., value = T) %>%
    grep("station", ., value = T) %>%
    paste0("http://en.wikipedia.org",.)
}

# function to extract coordinates from a station page
ExtractGeo <- function(url) {
  # takes a URL and uses the CSS selector provided by SelectorGadget widget to
  # extract the dirty coordinates data from it
  url %>%
    html() %>%
    html_nodes("span span span span span span.geo") %>%
    html_text()
}

# function to extract station name
ExtractTitle <- function(url) {
  # takes a URL and uses the CSS selector provided by SelectorGadget widget to
  # extract the first header, which in this case is the wikipedia page title
  url %>%
    html() %>%
    html_nodes("div h1") %>%
    html_text()
}


# if the stations data doesn't exist -------------------------------------------
  if (!file.exists("./data/stations.csv")) {

  ########################## Get the raw data to be used #########################
# rail stations Data from Wikipedia --------------------------------------------
# get railway stations information
  railStations <- GetRailStations()

# tube stations Data from Wikipedia --------------------------------------------
# starting from Baker St, find all links on the page
  links <- ExtractLinks()

# loop over the links and try to extract the coordinates from the page
  geos <- sapply(1:length(links), function(x) try(ExtractGeo(links[x]), silent = T))

# clean up the coordinates
  geos.clean <- sapply(1:length(geos), function(x) geos[[x]][1])

# loop over the links and extract the station name from the page
  titles <- sapply(1:length(links), function(x) try(ExtractTitle(links[x]), silent = T))

# clean up the station names
  title.clean <- sapply(1:length(titles), function(x) titles[[x]][1])

# combine in to one data frame
  locations <- cbind(geos.clean, title.clean) %>% data.frame()

# clean up
  rm(list = c("links", "geos","geos.clean", "titles", "title.clean"))
  gc()

############################# Clean the data ##################################
# set the names to lower case because I'm lazy
  names(railStations) %<>% make.names() %>% tolower()
  names(locations) %<>% tolower

# Rail stations data -----------------------------------------------------------
# extract lat/long
  coordsRaw  <-  railStations$coordinates %>% str_split("/")

# clean up
  coordsClean <- sapply(1:length(coordsRaw), function(x) coordsRaw[[x]][[3]]) %>%
    str_trim() %>%
    str_split(";")

lattitude <- sapply(1:length(coordsClean), function(x) coordsClean[[x]][1]) %>%
             str_trim() %>%
             as.numeric()

longitude <- sapply(1:length(coordsClean), function(x) coordsClean[[x]][2]) %>%
             str_trim() %>%
             str_extract("-[0-9].[0-9]*|[0-9].[0-9]*") %>%
             as.numeric()


# add latt and long back to data frame
  railStations %<>% mutate(long = longitude,
                         lat = lattitude) %>%
                    select(-coordinates)

# clean up
  rm(list = c("coordsRaw", "coordsClean", "lattitude", "longitude"))
  gc()

# Tube stations data -----------------------------------------------------------
# find those pages that weren't really stations/where the link didn't work
  errors <- grep("[Tt]alk|[Gg]roup|[Cc]ategory|[Ee]rror|[Cc]hanges|[Pp]ages|[Ff]ile|[Ll]ist", locations$title.clean)

# cut out the broken links and take unique values
  locations <- locations[-errors,] %>% unique()

# split up the coordinates (currently lat and long in one field)
  geoSplit <- str_split(locations$geos.clean, ";")

# pick up lat
  lat <- sapply(1:length(geoSplit), function(x) geoSplit[[x]][1]) %>% as.numeric

# pick up long
  long <- sapply(1:length(geoSplit), function(x) geoSplit[[x]][2]) %>% as.numeric

# combine in to one data set
  tubeStations <- data.frame(station = locations$title.clean, long, lat)

# clean up
  rm(list = c("errors", "locations", "geoSplit", "lat", "long"))
  gc()

# combine all stations w/ coordinates in to one --------------------------------
stations <- railStations %>% select(station, long, lat) %>%
            rbind(tubeStations) %>%
            arrange(station) %>%
            unique()

# clean up
  rm(list = c("railStations", "tubeStations"))
  gc()


# clean combined data set station names ----------------------------------------
stations$station %<>%
  gsub("\\[.*\\]|[Tt]ube|[Ss]tation|[Rr]ailway| [Dd][Ll][Rr]|\\(.*\\)",
       "", .) %>%
  str_trim()

# clean indidivual station names that do not match to oyster data --------------
# Kings Cross
  missing <- grep("King's", stations$station)
  stations[missing, 1] <- "Kings Cross"

# Bank
  missing <- grep("Bank", stations$station)
  stations[missing, 1] <- "Bank"

# Old Street
  missing <- grep("[Oo]ld Stree", stations$station)
  stations[missing, 1] <- "Old Street"

# Caledonian Road
  missing <- grep("[Cc]ale", stations$station)
  stations[missing, 1] <- "Caledonian Road and Barnsbury"

# get and add in missing staions -----------------------------------------------
missing <- c("http://en.wikipedia.org/wiki/Leicester_Square_tube_station",
                     "http://en.wikipedia.org/wiki/Kennington_tube_station",
                     "http://en.wikipedia.org/wiki/Warren_Street_tube_station",
                     "http://en.wikipedia.org/wiki/Covent_Garden_tube_station",
                     "http://en.wikipedia.org/wiki/Mornington_Crescent_tube_station",
                     "http://en.wikipedia.org/wiki/Camden_Town_tube_station",
                     "http://en.wikipedia.org/wiki/Pimlico_tube_station",
                     "http://en.wikipedia.org/wiki/Goodge_Street_tube_station",
                     "http://en.wikipedia.org/wiki/Hyde_Park_Corner_tube_station",
                     "http://en.wikipedia.org/wiki/Earl%27s_Court_tube_station",
                     "http://en.wikipedia.org/wiki/Hounslow_East_tube_station",
                     "http://en.wikipedia.org/wiki/Angel_tube_station")

missing.geos <- sapply(1:length(missing), function(x) missing[[x]] %>%
                         ExtractGeo()) %>% str_split(";")

lattitude <- sapply(1:length(missing.geos), function(x) missing.geos[[x]][1]) %>%
             str_trim() %>%
             as.numeric()

longitude <- sapply(1:length(missing.geos), function(x) missing.geos[[x]][2]) %>%
             str_trim() %>%
             str_extract("-[0-9].[0-9]*|[0-9].[0-9]*") %>%
             as.numeric()


missing.titles <- sapply(1:length(missing), function(x) missing[[x]] %>%
                                    ExtractTitle()) %>%
                  gsub(" [Tt]ube [Ss]tation|\\'", "", .) %>%
                  str_trim()

missing <- data.frame(station = missing.titles,
                      long = longitude,
                      lat = lattitude)


# final clean up ---------------------------------------------------------------
# clean up and strip out duplicates
stations %<>%
  rbind(missing) %>%
  group_by(station) %>%
  mutate(rank = row_number(station)) %>%
  filter(rank == 1) %>%
  select(-rank)

write.csv(stations, "./data/stations.csv", row.names = F)

# clean up directory
  rm(list = c("missing", "missing.geos", "longitude", "lattitude",
              "missing.titles", "stations"))
} else {
# read in the data -------------------------------------------------------------
stations <- read.csv("./data/stations.csv", header = T, stringsAsFactors = F)
}


