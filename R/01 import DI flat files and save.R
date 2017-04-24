# Code by Mark Agerton (2017-04)

# Ingests unzipped DI Desktop Raw Data PLUS flat files
# Saves to .Rdata and .dta (Stata 12) formats
# SET 

# Can run from the command line with 
# "C:\Program Files\R\R-3.3.2\bin\Rscript.exe" "R\00a NEW initial import of data.R"

rm(list=ls())

# CONSTANTS
DATE_DI_FILES <- "-2017-03-31"                # suffix for filenames with version of DI files
DIR_RAW_TEXT  <- "./tmp/"                     # where DI text files reside
DIR_SAVE_R    <- "./intermediate_data/"       # where to save .Rdata files
DIR_SAVE_DTA  <- "./intermediate_data/dta/"   # where to save .dta files

# OPTIONS
REPLACE_DTA_WITH_GZIP <- TRUE   # whether to delete .dta files after gzipping
NUM_ROWS              <- -1L    # number of rows to read in (-1L is all)
COMPRESS              <- TRUE   # compress .Rdata files on base::save()?
COMPRESSION_LEVEL     <- 4      # when saving .Rdata files

# optionally install packages with
# install.packages(c("haven", "lubridate", "readr", "R.utils", "data.table"))

library(haven)
library(lubridate)
library(readr)
library(R.utils)
library(data.table)

# load in the lightly formatted "DI Desktop Raw Data PLUS.docx" document
source("R/Table Schema Definitions.R")

# ------------------ read in schema definitions from DI documentation and conver to data frame -----------------

# make data.tables of column types & descriptions
makedf <- function(x) data.frame(field = names(x), info = x, order = 1:length(x))

desc <- data.table( melt(lapply(table_field_labels, makedf), id.vars = c("field", "order")) )
typs <- data.table( melt(lapply(table_field_types,  makedf), id.vars = c("field", "order")) )

# drop extraneous cols
desc[, variable := NULL]
typs[, variable := NULL]

# fix names
setnames(typs, "value", "oracle_type")
setnames(desc, "value", "description")
setnames(desc, "L1", "table")
setnames(typs, "L1", "table")

# fix mispelled columns
desc[table == "PDEN_DESC" & field == "LATEST_WNCT"    , field := "LATEST_WCNT"]
desc[table == "PDEN_DESC" & field == "YEILD"          , field := "YIELD"]
desc[table == "PERMITS"   & field == "CURR_OPER_NAME" , field := "OPER_NAME"]
desc[table == "PERMITS"   & field == "CURR_OPER_NO"   , field := "OPER_NO"]
desc[table == "PERMITS"   & field == "FIELD"          , field := "FIELD_NAME"]
desc[table == "PERMITS"   & field == "ZIP"            , field := "OPER_ZIP"]

typs[table == "PERMITS"   & field == "QTRQTR"         , field := "QTR_QTR"]
typs[table == "PERMITS"   & field == "RES_NAME"       , field := "RESERVOIR"]
typs[table == "PERMITS"   & field == "FORM_"          , field := "FORM_3"]

# ------------------ translate DI column types to R col types-----------------

# merge tables with column types & descriptions on field name
column_info <- merge(typs, desc, by = c("table", "field"), all=T)[order(table, order.x)]
rm(desc, typs)

# are any fields unmatched??
column_info[is.na(description) | is.na(oracle_type), .(field, table, order.x, order.y, is.na(description))]

# Does the order of the column types and descriptions provided in the DI document match?
# If the data.table has non-zero length, then the order does NOT match. 
# I am assuming that the order of columns in the column type definitions is correct
column_info[order.x != order.y]

# assign R atomic types
# column_info[,.N, keyby=.(oracle_type)]
column_info[oracle_type == "DATE"                                     , r_class := "Date"]
column_info[oracle_type %like% "NUMBER\\([456]\\)"                    , r_class := "integer"]
column_info[oracle_type %like% "NUMBER\\([91]\\d?\\)" & is.na(r_class), r_class := "numeric"]
column_info[oracle_type == "NUMBER(38)"                               , r_class := "character"]
column_info[oracle_type %like% "NUMBER\\(\\d+,\\d+\\)"                , r_class := "numeric"]
column_info[oracle_type %like% "VARCHAR"                              , r_class := "character"]
column_info[oracle_type == "NUMBER"                                   , r_class := "integer"]
column_info[table == "PDEN_PROD" & field %in% c("LIQ", "GAS", "WTR")  , r_class := "numeric"]

# translate to read_r column classes
column_info[ r_class == "Date"     , readr_class := "D"]
column_info[ r_class == "integer"  , readr_class := "i"]
column_info[ r_class == "numeric"  , readr_class := "d"]
column_info[ r_class == "character", readr_class := "c"]

# # anything not classified?
# column_info[is.na(r_class) | is.na(readr_class), .N, keyby=.(oracle_type, r_class)]

# ------------------ which columns should be factors (to save space) -----------------

# designate these columns as factors
to_factors <- list(
  `NPH_BOTMHOLES`  = c("RELIABILITY", "DRILL_TYPE"),
  `NPH_OPER_ADDR`  = c("ADDR_TYPE", "STATE_ABRV", "COUNTRY"),
  `NPH_WELLSPOTS`  = c("STATE", "RELIABILITY", "PROD_TYPE", "STATUS", "DRILL_TYPE", "ELEVATION_TYPE"),
  `PDEN_DESC`      = c("DISTRICT", "PDEN_TYPE", "PROD_TYPE", "STATE", "COUNTRY", "COUNTY_ID", "COUNTY", "STATUS", "DRILL_TYPE", 
                       "ELEVATION_TYPE", "OCS_AREA", "ALLOC_PLUS", "PROD_TYPE", "OFFSHORE", "SECTION", "MERID", "BASIN", "PGC_AREA", "TWP", "RNG"),
  `PDEN_SALE`      = c("PROD_TYPE"),
  `PDEN_WELL_TEST` = c("POTENTIAL_CALC", "BHP_CALC", "TEST_TYPE", "PROD_METHOD"),
  `PERMITS`        = c("DISTRICT", "COUNTY", "H2S_AREA", "PDEN_TYPE", "DRILL_TYPE", "PERMIT_TYPE", "COUNTY_ID", "STATUS", "RIG_PRESENT", 
                       "DRIL_STATE", "APPROVED", "COMP_EXISTS", "PURPOSE", "CASE_NO", "OPER_STATE", "STATE", "SECTION", "BASIN", "DRILLER", 
                       "DRILLER_PHONE", "TWN_SL", "TWNDIR_SL", "RNG_SL", "RNGDIR_SL", "SEC_BH", "TWN_BH", "TWNDIR_BH", "RNG_BH", 
                       "RNGDIR_BH", "DRIL_CITY", "DRIL_ZIP")
)

# add this informations as T/F column
for (tbl in names(to_factors)) {
  column_info[ table == tbl & field %in% to_factors[[tbl]], is_factor := TRUE]
}

column_info[is.na(is_factor), is_factor := FALSE]

# ------------------ save column_info -----------------

save(column_info, file = paste0(DIR_SAVE_R, "/column_info.Rdata"))

# ----------------- import all tables except PDEN_PROD -------------------- 
# use readr::read_csv() to import because it deals with embedded nul characters

tbls <- column_info[table != "PDEN_PROD", unique(table)]
names(tbls) <- tbls

# lapply saves to .Rdata and returns import problems to global workspace
problems <- lapply(tbls, function(TABLE_NAME){

  # get col names, types, and descriptions
  table_name <- tolower(TABLE_NAME)
  file <- paste0(DIR_RAW_TEXT, TABLE_NAME, ".txt")
  col_names   <- column_info[(column_info$table == TABLE_NAME), tolower(field)]
  col_classes <- column_info[(column_info$table == TABLE_NAME), readr_class]
  col_labels  <- column_info[(column_info$table == TABLE_NAME), description]
  names(col_labels) <- col_names

  # read in CSV using readr::read_csv() and convert to data.table
  cat(paste0(Sys.time(), " starting import of ", table_name, "\n"))
  assign(
    x = table_name,
    value = data.table(read_csv(   # use read_csv()
        file = file,
        n_max = NUM_ROWS,
        na = c("NA", "(N/A)"),
        locale = locale(encoding = "ISO-8859-1"),
        col_names = col_names,
        col_types = paste0(col_classes, collapse="")
      )
  ))

  cat(paste0(Sys.time(), " adding factors and labels ", table_name, "\n"))
  
  # update appropriate columns to factors BY REFERENCE using data.table so don't have to make copies in memory
  factor_cols <- column_info[table == TABLE_NAME & is_factor == T, tolower(field)]
  for (fc in factor_cols) {
    eval(parse(text=table_name))[, (fc) := factor(get(fc))]
  }
  
  # set column labels by reference
  for (c in names(col_labels)) {
    parsecol <- paste0(table_name, '[[ "', c, '" ]]')
    setattr(eval(parse(text=parsecol)), "label", col_labels[c])
  }
  
  # get list of import problems
  probs <- data.table(problems(eval(parse(text=table_name))))
  probs[, table := table_name]
  
  # save to R
  cat(paste0(Sys.time(), " saving ", table_name, " as R\n"))
  save(list = table_name,
       file = paste0(DIR_SAVE_R,table_name, DATE_DI_FILES,".Rdata"),
       compress = COMPRESS, 
       compression_level = COMPRESSION_LEVEL
  )

  # clean up
  rm(list = table_name)
  gc()
  
  # return problems
  cat(paste0("Done.\n"))
  return(probs)
})

# generate big list of import problems.
# Why does Windows find embeded nulls but Unbuntu not??
DI_import_problems <- do.call(rbind, problems)
save(DI_import_problems, file = paste0(DIR_SAVE_R, "DI_import_problems", DATE_DI_FILES, ".Rdata"))
gc()

# ----------------- import PDEN_PROD -------------------- 
# use data.table::fread() because it has lower memory usage (and is faster)

TABLE_NAME <- "PDEN_PROD"
table_name <- tolower(TABLE_NAME)
file <- paste0(DIR_RAW_TEXT, TABLE_NAME, ".txt")
col_names   <- column_info[(column_info$table == TABLE_NAME), tolower(field)]
col_classes <- column_info[(column_info$table == TABLE_NAME), r_class]
col_labels  <- column_info[(column_info$table == TABLE_NAME), description]
names(col_labels) <- col_names

cat(paste0(Sys.time(), " starting import of ", table_name, "\n"))
pden_prod <- fread(  # use fread
      file = file,
      nrows = NUM_ROWS,
      header = FALSE,
      verbose = TRUE,
      stringsAsFactors = FALSE,
      sep = ",",
      colClasses = col_classes,
      col.names = col_names,
      na.strings = c("NA", "(N/A)"),
      encoding = "Latin-1",
      showProgress = TRUE,
      data.table = TRUE
)

# convert date column to date by reference
cat(paste0(Sys.time(), " converting to Date col ", table_name, "\n"))
pden_prod[, prod_date := as.Date(lubridate::parse_date_time(prod_date,'%y-%m-%d'))]

# add variable labels by reference
cat(paste0(Sys.time(), " adding variable labels to ", table_name, "\n"))
for (c in names(col_labels)) {
  setattr(pden_prod[[c]], "label", col_labels[c])
}

# save to R
cat(paste0("saving ", table_name, " as R\n"))
save(list = table_name, 
     file = paste0(DIR_SAVE_R, tolower(table_name), DATE_DI_FILES, ".Rdata"), 
     compress = COMPRESS, 
     compression_level = COMPRESSION_LEVEL
)

# clean up
rm(list = table_name)
gc()

# --------------- save to stata -------------------

# # column info
# load(file = paste0(DIR_SAVE_R, "/column_info.Rdata"))

# all the tables
tbls <- tolower( column_info[, unique(table)])

for (table_name in tbls) {
  # .Rdata files
  f_in  <- paste0(DIR_SAVE_R,   table_name, DATE_DI_FILES, ".Rdata")
  f_out <- paste0(DIR_SAVE_DTA, table_name, DATE_DI_FILES, ".dta")
  
  cat(paste0(Sys.time(), " loading ", table_name, "\n"))
  load(f_in)
  
  cat(paste0(Sys.time(), " writing to stata ", table_name, "\n"))
  haven::write_dta(eval(parse(text=table_name)), path=f_out, v=12)
  
  cat(paste0(Sys.time(), " gzipping ", table_name, "\n"))
  R.utils::gzip(filename = f_out, overwrite = TRUE, remove = REPLACE_DTA_WITH_GZIP)
  
  cat(paste0(Sys.time(), " done. cleanup. ", table_name, "\n"))
  rm(list=table_name)
  gc()
}

# # AFTER
# rsync -chavzP -f '- /*/*/' --stats rstudio@184.72.195.76:tx-price-diffs/intermediate_data /d/projects/tx-price-diffs/



