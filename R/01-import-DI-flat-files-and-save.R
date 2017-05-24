# Code by Mark Agerton (2017-04)
# Thanks to Ben Weintraut for reviewing code (2017-05)

# Ingests unzipped DI Desktop Raw Data PLUS flat files
# Saves to .Rdata and .dta (Stata) formats

# Can run from the command line with 
# "C:\Program Files\R\R-3.3.2\bin\Rscript.exe" "R\01-import-DI-flat-files-and-save.R"

rm(list=ls())

# PARAMETERS
DATE_DI_FILES <- "-2017-04-30"                # suffix for filenames with version/date of DI files
DIR_RAW_TEXT  <- "./tmp/"                     # where DI text files reside
DIR_SAVE_R    <- "./intermediate_data/"       # where to save .Rdata files
DIR_SAVE_DTA  <- "./intermediate_data/dta/"   # where to save .dta files

# OPTIONS: import
CONVERT_PROD_CHARDATE_TO_DATE <- TRUE   # convert string to date when importing PDEN_PROD table? This seems to increase RAM requirements
NUM_ROWS                      <- -1L    # num rows to read for each table (-1L is all. Change to positive integer for testing.)

# OPTIONS: saving to R .Rdata
COMPRESS                      <- TRUE   # compress .Rdata files on base::save()?
COMPRESSION_LEVEL             <- 4      # Gzip compression level when saving .Rdata files

# OPTIONS: saving to Stata .dta
SAVE_TO_STATA                 <- TRUE   # After importing flat-files to R, save to Stata format?
GZIP_DTA_FILES                <- TRUE   # should we gzip (compress) the .dta files?
USE_PIGZ                      <- FALSE  # TRUE: use system command for parallel gzip of dta files; FALSE: use R.utils::gzip. Requies pigz to be on system path
REPLACE_DTA_WITH_GZIP         <- TRUE   # Delete .dta files after gzipping?
STATA_VERSION                 <- 12     # version of saved Stata .dta files

# uncomment line below to install packages
# install.packages(c("haven", "lubridate", "readr", "R.utils", "data.table"))

library(haven)
library(lubridate)
library(readr)
library(R.utils)
library(data.table)

# load in the lightly formatted "DI Desktop Raw Data PLUS.docx" document
source("R/Table-Schema-Definitions.R")

# ------------------ read in schema definitions from DI documentation and convert to data frame -----------------

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
setnames(typs, "L1", "table")
setnames(desc, "L1", "table")
setnames(typs, "order", "order_col_desc")
setnames(desc, "order", "order_col_type")

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

# merge tables with column types & descriptions on field name; preserving order of types
column_info <- merge(typs, desc, by = c("table", "field"), all=T)[order(table, order_col_type)]
rm(desc, typs)

# The order of columns in the DI column type definitions (NOT column descriptions) corresponds to the flat-files
setattr(column_info$order_col_type, "label", "Order column types listed in 'DI Desktop Raw Data PLUS.docx'")
setattr(column_info$order_col_desc, "label", "Order column descriptions listed in 'DI Desktop Raw Data PLUS.docx'")

# assign R atomic types
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

# ------------------ save column_info to .Rdata & .csv -----------------

col_order <- c("table", "field", "order_col_type", "order_col_desc", "oracle_type", "r_class", "readr_class", "is_factor", "description")

save(column_info, file = paste0(DIR_SAVE_R, "/column_info.Rdata"))
write_csv(column_info[ , .SD, .SDcols = col_order], path = paste0(DIR_SAVE_R, "/column_info.csv"))

# ----------------- import all tables except PDEN_PROD -------------------- 

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
  factor_cols <- column_info[table == TABLE_NAME & is_factor == T, tolower(field)]
  
  names(col_labels) <- col_names

  # read in CSV using readr::read_csv() because it reports any import problems
  # Use non-standard evaluation so that we can use just one function for each tables
  cat(paste0(Sys.time(), " starting import of ", table_name, "\n"))
  assign(
    x = table_name,
    value = read_csv(  
        file = file,
        n_max = NUM_ROWS,
        na = c("NA", "(N/A)"),
        locale = locale(encoding = "ISO-8859-1"),
        col_names = col_names,
        col_types = paste0(col_classes, collapse="")
  ))
  
  # get table of import problems & add table name
  probs <- data.table(problems(eval(parse(text=table_name))))
  probs[, table := table_name]
  
  # convert from tibble to data.table for easy updating in-place / by reference (versus copying)
  cat(paste0(Sys.time(), " Convert ", table_name, " from tibble to data.table\n"))
  setDT(eval(parse(text=table_name)))
  
  # update appropriate columns to factors BY REFERENCE using data.table so don't have to make copies in memory
  cat(paste0(Sys.time(), " converting factor variables in ", table_name, "\n"))
  for (fc in factor_cols) {
    eval(parse(text=table_name))[, (fc) := factor(get(fc))]
  }
  
  # set column labels by reference
  cat(paste0(Sys.time(), " adding variable labels ", table_name, "\n"))
  for (c in names(col_labels)) {
    parsecol <- paste0(table_name, '[[ "', c, '" ]]')
    setattr(eval(parse(text=parsecol)), "label", col_labels[c])
  }
  
  # save to R. Would be nice to use pigz or another compression algorithm to speed this up.
  cat(paste0(Sys.time(), " saving ", table_name, " as .Rdata\n"))
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

# Assemble data.table of any import problems thyat have come up.
DI_import_problems <- do.call(rbind, problems)

if (nrow(DI_import_problems) > 0) {
  
  fn <- paste0(DIR_SAVE_R, "DI_import_problems", DATE_DI_FILES, ".Rdata")
  cat(paste(Sys.time(), nrow(DI_import_problems), "possible parsing failures. Saving to", fn, "\n"))
  save(DI_import_problems, file = fn)

  } else {

  cat(paste(Sys.time(), nrow(DI_import_problems), "parsing failures found.\n"))

}

# ----------------- import PDEN_PROD --------------------

TABLE_NAME <- "PDEN_PROD"
table_name <- "pden_prod"
file <- paste0(DIR_RAW_TEXT, "PDEN_PROD.txt")
col_names   <- column_info[table == "PDEN_PROD", tolower(field)]
col_classes <- column_info[table == "PDEN_PROD", paste0(readr_class, collapse = "")]
colClasses  <- column_info[table == "PDEN_PROD", r_class]
col_labels  <- column_info[table == "PDEN_PROD", description]
names(col_labels) <- col_names

if (CONVERT_PROD_CHARDATE_TO_DATE == TRUE) {
  
  cat(paste0(Sys.time(), " starting import of ", table_name, " WITH date conversion\n"))
  
  # use read_csv because it converts character to date
  pden_prod <- read_csv(
    file = file,
    n_max = NUM_ROWS,
    na = c("NA", "(N/A)"),
    locale = locale(encoding = "ISO-8859-1"),
    col_names = col_names,
    col_types = paste0(col_classes, collapse="")
  )
  
  # convert from tibble to data.table for easy updating in-place / by reference (versus copying)
  cat(paste0(Sys.time(), " Convert ", table_name, " from tibble to data.table\n"))
  setDT(pden_prod)

} else {
  
  cat(paste0(Sys.time(), " starting import of ", table_name, " WITHOUT date conversion\n"))
  
  # use fread because of lower memory requirements
  pden_prod <- fread(
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
}

# add variable labels by reference
cat(paste0(Sys.time(), " adding variable labels to ", table_name, "\n"))
for (c in names(col_labels)) {
  setattr(pden_prod[[c]], "label", col_labels[c])
}

# save to R. Would be nice to use pigz or another compression algorithm to speed this up.
cat(paste0("saving ", table_name, " as R\n"))
save(pden_prod, 
     file = paste0(DIR_SAVE_R, "pden_prod", DATE_DI_FILES, ".Rdata"),
     compress = COMPRESS,
     compression_level = COMPRESSION_LEVEL
)

# clean up
rm(pden_prod)
gc()
 
# --------------- save to stata -------------------

if (SAVE_TO_STATA == TRUE) {

  # all the tables
  tbls <- tolower( column_info[, unique(table)])
  
  for (table_name in tbls) {
    # .Rdata files
    f_in  <- paste0(DIR_SAVE_R,   table_name, DATE_DI_FILES, ".Rdata")
    f_out <- paste0(DIR_SAVE_DTA, table_name, DATE_DI_FILES, ".dta")
  
    # load files
    cat(paste0(Sys.time(), " loading ", table_name, "\n"))
    load(f_in)
  
    # write to Stata using haven::write_dta()
    cat(paste0(Sys.time(), " writing to stata ", table_name, "\n"))
    write_dta(eval(parse(text=table_name)), path=f_out, v=STATA_VERSION)
  
    # compress dta files?
    if (GZIP_DTA_FILES == TRUE) {
      cat(paste0(Sys.time(), " gzipping ", table_name, "\n"))
  
      if (USE_PIGZ == TRUE) {
        system2(command = 'pigz',
                args = paste(
                  ifelse(REPLACE_DTA_WITH_GZIP == TRUE, "", "--keep"),  # delete .dta after gzip?
                  "--force",                                            # overwrite existing .gz files
                  f_out                                                 # compressed file name
                )
        )
      } else {
        R.utils::gzip(filename = f_out, overwrite = TRUE, remove = REPLACE_DTA_WITH_GZIP)
      }
    }
  
    cat(paste0(Sys.time(), " done. cleanup. ", table_name, "\n"))
    rm(list=table_name)
    gc()
  }
}
