# Code by Mark Agerton (2017-04)
# 
# This file is simply a set of commands to open each table saved in the prior script

rm(list=ls())

library(data.table)

DATE_DI_FILES <- "-2017-03-31"

# import column info
load("intermediate_data/column_info.Rdata")
column_info[,.N, keyby=table]
column_info[is_factor == T, .(table, field)]

# what import problems were there in all but PDEN_PROD table?
# Why did Windows find embedded nulls but Linux not?
load(paste0("intermediate_data/DI_import_problems", DATE_DI_FILES, ".Rdata"))
problems

load(paste0("intermediate_data/nph_api_nos"   , DATE_DI_FILES, ".Rdata"))
nph_api_nos
sapply(nph_api_nos, class)

load(paste0("intermediate_data/nph_botmholes" , DATE_DI_FILES, ".Rdata"))
nph_botmholes
sapply(nph_botmholes, class)

load(paste0("intermediate_data/nph_oper_addr" , DATE_DI_FILES, ".Rdata"))
nph_oper_addr
sapply(nph_oper_addr, class)

load(paste0("intermediate_data/nph_pden_tops" , DATE_DI_FILES, ".Rdata"))
nph_pden_tops
sapply(nph_pden_tops, class)

load(paste0("intermediate_data/nph_wellspots" , DATE_DI_FILES, ".Rdata"))
nph_wellspots
sapply(nph_wellspots, class)

load(paste0("intermediate_data/pden_desc"     , DATE_DI_FILES, ".Rdata"))
pden_desc
sapply(pden_desc, class)

load(paste0("intermediate_data/pden_inj"      , DATE_DI_FILES, ".Rdata"))
pden_inj
sapply(pden_inj, class)


load(paste0("intermediate_data/pden_sale"     , DATE_DI_FILES, ".Rdata"))
pden_sale
sapply(pden_sale, class)

load(paste0("intermediate_data/pden_well_test", DATE_DI_FILES, ".Rdata"))
pden_well_test
sapply(pden_well_test, class)

load(paste0("intermediate_data/permits"       , DATE_DI_FILES, ".Rdata"))
permits
sapply(permits, class)
