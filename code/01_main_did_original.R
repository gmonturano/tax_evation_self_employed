############################################################
############ DID CONTINUO - 4 ROBUSTEZZE REFEREE ###########
############################################################

############# librerie ##############

library(sf)
library(ggplot2)
library(tmap)
library(tmaptools)
library(leaflet)
library(dplyr)
library(tidyr)
library(LabRS)
library(tidyverse)
library(RColorBrewer)
library(summarytools)
library(writexl)
library(desc)
library(readxl)
library(patchwork)
library(viridis)
library(cowplot)
library(openxlsx)
library(data.table)
library(stringr)
library(gridExtra)
library(lubridate)
library(readr)
library(plm)
library(jtools)

############################################################
############ parametri #####################################
############################################################

pre_last_year  <- 2007
post_first_year <- 2008
post_years <- 2008:2015

# Path originali
path_dataset <- "G:/.shortcut-targets-by-id/1N5PkCFxVvERZMdwYsTfrBxhrACLaYmqo/microdati trimestrali RCFL/dataset"
path_output  <- "G:\\.shortcut-targets-by-id\\1N5PkCFxVvERZMdwYsTfrBxhrACLaYmqo\\microdati trimestrali RCFL\\Outcome"

############################################################
############ funzione export pulita ########################
############################################################

clean_export_summs <- function(summary_export){
  
  summary_export <- data.frame(summary_export)
  summary_export_1 <- summary_export
  
  num_cols <- ncol(summary_export)
  
  for (i in 2:num_cols) {
    col_name <- paste0("Asterisco_", i - 1)
    summary_export[[col_name]] <- sapply(summary_export[, i], function(x) {
      num_asterisks <- nchar(gsub("[^\\*]", "", x))
      if (num_asterisks > 0) {
        paste(rep("*", num_asterisks), collapse = "")
      } else {
        ""
      }
    })
    summary_export[, i] <- gsub("\\*", "", summary_export[, i])
  }
  
  num_columns <- min(
    length(grep("^Model\\.", colnames(summary_export))),
    length(grep("^Asterisco_", colnames(summary_export)))
  )
  
  model_cols <- grep("^Model\\.", colnames(summary_export), value = TRUE)[1:num_columns]
  asterisco_cols <- grep("^Asterisco_", colnames(summary_export), value = TRUE)[1:num_columns]
  
  summary_export_new <- summary_export[, c(rbind(model_cols, asterisco_cols))]
  
  nuovi_nomi <- c()
  for (i in 1:ncol(summary_export_new)) {
    if (i %% 2 == 1) {
      nuovi_nomi <- c(nuovi_nomi, paste0("Model.", (i + 1) %/% 2))
    } else {
      nuovi_nomi <- c(nuovi_nomi, paste0("Asterisco_", i %/% 2))
    }
  }
  colnames(summary_export_new) <- nuovi_nomi
  
  summary_export_new <- apply(summary_export_new, 2, function(x) gsub("[()]", "", x))
  summary_export_new <- summary_export_new[-1, ]
  
  summary_export_1_1 <- summary_export_1[-1, ]
  summary_export_1_1 <- data.frame(summary_export_1_1[, 1])
  colnames(summary_export_1_1) <- "names"
  
  summary_export_new <- cbind(summary_export_1_1, summary_export_new)
  
  numero_colonne <- ncol(summary_export_new)
  colonne_da_convertire <- seq(2, numero_colonne, by = 2)
  
  summary_export_new[, colonne_da_convertire] <- lapply(
    summary_export_new[, colonne_da_convertire],
    as.numeric
  )
  
  colonne_numeriche <- sapply(summary_export_new, is.numeric)
  summary_export_new[, colonne_numeriche] <- lapply(
    summary_export_new[, colonne_numeriche],
    function(x) round(x, 3)
  )
  
  for (i in seq(2, ncol(summary_export_new), by = 2)) {
    for (j in seq(2, ncol(summary_export_new), by = 2)) {
      if (!is.na(summary_export_new[i, j])) {
        if (i %% 2 == 0) {
          summary_export_new[i, j] <- paste0("(", summary_export_new[i, j], ")")
        } else {
          summary_export_new[i, j] <- paste0(summary_export_new[i, j], ".000")
        }
      }
    }
  }
  
  for (col in names(summary_export_new)) {
    if (startsWith(col, "Asterisco_")) {
      model_col_index <- match(sub("Asterisco_", "Model.", col), names(summary_export_new))
      model_values <- summary_export_new[[model_col_index]]
      asterisco_values <- summary_export_new[[col]]
      model_values[model_values == "NA"] <- NA
      summary_export_new[[model_col_index]] <- ifelse(
        is.na(model_values),
        NA,
        paste0(model_values, asterisco_values)
      )
    }
  }
  
  start_column <- 3
  summary_export_new <- summary_export_new[
    ,
    c(1:(start_column - 1), seq(start_column + 1, ncol(summary_export_new), 2))
  ]
  
  return(summary_export_new)
}

############################################################
############ carico dati e costruisco base #################
############################################################

setwd(path_dataset)
load("final_merged_dataset.RData")

db_base <- final_merged_utf8_merge

db_base$dummy_policy <- ifelse(db_base$year >= post_first_year, 1, 0)

# Variabili da fissare/pre-mediare.
exposure_vars <- c(
  "redditti_provincia_autono",
  "self_empl_sh",
  "prof3_oth_noncogn_sk_high",
  "prof3_basic_sk_high",
  "prof3_cogn_sk_high",
  "prof3_horizontal_sk_high",
  "prof3_soft_sk_high"
)
exposure_vars <- exposure_vars[exposure_vars %in% names(db_base)]

# Valori 2007.
expo_2007 <- db_base %>%
  filter(year == pre_last_year) %>%
  select(COD_PROV, all_of(exposure_vars)) %>%
  distinct(COD_PROV, .keep_all = TRUE)

names(expo_2007)[names(expo_2007) %in% exposure_vars] <- paste0(exposure_vars, "_2007")

# Medie pre-riforma: tutti gli anni < 2008 disponibili nel dataset.
expo_premean <- db_base %>%
  filter(year < post_first_year) %>%
  group_by(COD_PROV) %>%
  summarise(across(all_of(exposure_vars), ~ mean(.x, na.rm = TRUE)), .groups = "drop")

names(expo_premean)[names(expo_premean) %in% exposure_vars] <- paste0(exposure_vars, "_premean")

# Merge exposure.
db_base <- db_base %>%
  left_join(expo_2007, by = "COD_PROV") %>%
  left_join(expo_premean, by = "COD_PROV")

############################################################
############ PIL nazionale e outcome #######################
############################################################

valori_str <- c(
  "1,270,962", "1,287,529", "1,308,328", "1,326,675", "1,346,539",
  "1,398,284", "1,422,063", "1,426,716", "1,427,460", "1,450,270",
  "1,462,478", "1,490,923", "1,514,368", "1,501,603", "1,418,573",
  "1,443,247", "1,451,697", "1,416,148", "1,394,602", "1,391,953",
  "1,400,297"
)

reddito_nazionale <- as.numeric(gsub(",", "", valori_str))
year <- 1995:2015

tab_nuova <- data.frame(reddito_nazionale, year)

db_base <- inner_join(db_base, tab_nuova, by = "year")

db_base$reddito_primo_anno_2004 <- 1450270

db_base$variazione_pil_assulta <- db_base$reddito_nazionale - db_base$reddito_primo_anno_2004

db_base$variazione_pil_relativa_1 <- db_base$variazione_pil_assulta / db_base$reddito_primo_anno_2004

db_base$fattore_anno <- 1

db_base$variazione_pil_relativa_tot <- db_base$variazione_pil_relativa_1 + db_base$fattore_anno

db_base$outcome_tax_gap_sh <- db_base$variazione_pil_relativa_tot * db_base$tax_gap_sh

db_base$outcome_valore_agg_shz <- db_base$variazione_pil_relativa_tot * db_base$valore_agg_sh

############################################################
############ metadata ######################################
############################################################

metadata <- read_xlsx(file.path(path_dataset, "meta_amedeo.xlsx"), sheet = 2)
spec_columns <- grep("^Spec", colnames(metadata), value = TRUE)

setwd(path_output)

############################################################
############ funzioni scenario #############################
############################################################

zscore <- function(x){
  as.numeric((x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE))
}

# Questa funzione prepara il dataset per uno scenario statico:
# 1) fixed_2007: P_i,2007
# 2) premean: media pre-riforma
# 3) z_premean: media pre-riforma standardizzata
prepare_static_did <- function(db, scenario){
  
  db <- as.data.frame(db)
  
  if (scenario == "fixed_2007") {
    ref_income <- db$redditti_provincia_autono_2007
    ref_income_cont <- log(ref_income)
    ref_share <- db$self_empl_sh_2007
  }
  
  if (scenario == "premean") {
    ref_income <- db$redditti_provincia_autono_premean
    ref_income_cont <- log(ref_income)
    ref_share <- db$self_empl_sh_premean
  }
  
  if (scenario == "z_premean") {
    ref_income <- db$redditti_provincia_autono_premean
    ref_income_cont <- zscore(log(ref_income))
    ref_share <- zscore(db$self_empl_sh_premean)
  }
  
  med_ref <- median(ref_income, na.rm = TRUE)
  
  db$dummy_mediana <- ifelse(ref_income <= med_ref, 1, 0)
  db$dummy_mediana_inverta <- db$dummy_mediana
  db$trattamento_binario <- db$dummy_policy * db$dummy_mediana_inverta
  
  db$trattamento_continuo <- ifelse(
    db$year >= post_first_year & db$dummy_mediana == 1,
    ref_income_cont,
    0
  )
  
  db$self_empl_sh <- ifelse(
    db$year >= post_first_year & db$dummy_mediana == 1,
    ref_share,
    0
  )
  
  # Skill groups: manteniamo gli stessi nomi dei trattamenti originali.
  skill_map <- list(
    prof3_oth_noncogn_sk_high = "prof3_oth_noncogn_sk_high_treat",
    prof3_basic_sk_high = "prof3_basic_sk_high_treat",
    prof3_cogn_sk_high = "prof3_cogn_sk_high_treat",
    prof3_horizontal_sk_high = "prof3_horizontal_sk_high_treat",
    prof3_soft_sk_high = "prof3_soft_sk_high_treat"
  )
  
  for (v in names(skill_map)) {
    treatname <- skill_map[[v]]
    if (scenario == "fixed_2007") ref <- db[[paste0(v, "_2007")]]
    if (scenario == "premean") ref <- db[[paste0(v, "_premean")]]
    if (scenario == "z_premean") ref <- zscore(db[[paste0(v, "_premean")]])
    db[[treatname]] <- ifelse(db$year >= post_first_year & db$dummy_mediana == 1, ref, 0)
  }
  
  return(db)
}

# Scenario dinamico: year dummy x media pre-riforma.
# Sostituisce trattamento_binario e trattamento_continuo con variabili anno-per-anno.
prepare_dynamic_did <- function(db){
  
  db <- as.data.frame(db)
  
  ref_income <- db$redditti_provincia_autono_premean
  ref_income_cont <- log(ref_income)
  med_ref <- median(ref_income, na.rm = TRUE)
  
  db$dummy_mediana <- ifelse(ref_income <= med_ref, 1, 0)
  db$dummy_mediana_inverta <- db$dummy_mediana
  db$trattamento_binario <- db$dummy_policy * db$dummy_mediana_inverta
  db$trattamento_continuo <- ifelse(db$year >= post_first_year & db$dummy_mediana == 1, ref_income_cont, 0)
  
  dynamic_map <- list()
  
  # Binary dynamic.
  dyn_bin <- c()
  for (yr in post_years) {
    nm <- paste0("trattamento_binario_y", yr)
    db[[nm]] <- ifelse(db$year == yr & db$dummy_mediana == 1, 1, 0)
    dyn_bin <- c(dyn_bin, nm)
  }
  dynamic_map[["trattamento_binario"]] <- dyn_bin
  
  # Continuous dynamic.
  dyn_cont <- c()
  for (yr in post_years) {
    nm <- paste0("trattamento_continuo_y", yr)
    db[[nm]] <- ifelse(db$year == yr & db$dummy_mediana == 1, ref_income_cont, 0)
    dyn_cont <- c(dyn_cont, nm)
  }
  dynamic_map[["trattamento_continuo"]] <- dyn_cont
  
  return(list(data = db, dynamic_map = dynamic_map))
}

replace_dynamic_vars <- function(vars, dynamic_map){
  out <- c()
  for (v in vars) {
    if (v %in% names(dynamic_map)) {
      out <- c(out, dynamic_map[[v]])
    } else {
      out <- c(out, v)
    }
  }
  unique(out)
}

run_models <- function(db, sheet_name, wb, dynamic = FALSE, dynamic_map = NULL){
  
  Panel <- pdata.frame(db, index = c("COD_PROV", "year"))
  model_results <- list()
  
  for (i in seq_along(spec_columns)) {
    
    col <- spec_columns[i]
    
    control_vars <- metadata$names.Panel.[metadata[[col]] == "control_vars"]
    control_vars <- na.omit(control_vars)
    
    dependent_var <- metadata$names.Panel.[metadata[[col]] == "dependent_var"]
    dependent_var <- na.omit(dependent_var)
    
    independent_vars <- metadata$names.Panel.[metadata[[col]] == "independent_vars"]
    independent_vars <- na.omit(independent_vars)
    
    interaction_vars <- metadata$names.Panel.[metadata[[col]] == "interaction"]
    interaction_vars <- na.omit(interaction_vars)
    
    independent_vars <- c(independent_vars, interaction_vars)
    
    if (dynamic) {
      independent_vars <- replace_dynamic_vars(independent_vars, dynamic_map)
    }
    
    # Tengo solo variabili effettivamente presenti nel Panel per evitare errori se il metadata contiene altro.
    rhs_vars <- c(independent_vars, control_vars)
    rhs_vars <- rhs_vars[rhs_vars %in% names(Panel)]
    
    formula_sum <- as.formula(
      paste(dependent_var, "~", paste(rhs_vars, collapse = "+"))
    )
    
    model_sum <- plm(
      formula_sum,
      effect = "twoways",
      model = "within",
      data = Panel
    )
    
    model_results[[i]] <- model_sum
  }
  
  summary_export <- export_summs(
    model_results,
    scale = FALSE,
    digits = 3,
    stars = c("***" = 0.01, "**" = 0.05, "*" = 0.1)
  )
  
  summary_export_new <- clean_export_summs(summary_export)
  
  addWorksheet(wb, sheetName = sheet_name)
  writeData(wb, sheet = sheet_name, x = summary_export_new, startRow = 1, startCol = 1)
  
  check <- db %>%
    group_by(year) %>%
    summarise(
      mean_trattamento_binario = mean(trattamento_binario, na.rm = TRUE),
      mean_trattamento_continuo = mean(trattamento_continuo, na.rm = TRUE),
      sd_trattamento_continuo = sd(trattamento_continuo, na.rm = TRUE),
      .groups = "drop"
    )
  
  addWorksheet(wb, sheetName = paste0(substr(sheet_name, 1, 20), "_check"))
  writeData(wb, sheet = paste0(substr(sheet_name, 1, 20), "_check"), x = check)
  
  return(wb)
}

############################################################
############ lancio 4 scenari ##############################
############################################################

wb <- createWorkbook()

# 1. Exposure fissa al 2007.
db_fixed <- prepare_static_did(db_base, "fixed_2007")
wb <- run_models(db_fixed, "Fixed_2007", wb, dynamic = FALSE)

# 2. Exposure media pre-riforma.
db_premean <- prepare_static_did(db_base, "premean")
wb <- run_models(db_premean, "PreMean", wb, dynamic = FALSE)

# 3. Exposure media pre-riforma standardizzata.
db_zpremean <- prepare_static_did(db_base, "z_premean")
wb <- run_models(db_zpremean, "Z_PreMean", wb, dynamic = FALSE)

# 4. Dinamica: year dummy x exposure media pre-riforma.
dyn <- prepare_dynamic_did(db_base)
wb <- run_models(dyn$data, "Dynamic_PreMean", wb, dynamic = TRUE, dynamic_map = dyn$dynamic_map)

saveWorkbook(
  wb,
  "output_DID_4_robustezze_referee.xlsx",
  overwrite = TRUE
)

############################################################
############ fine ##########################################
############################################################
