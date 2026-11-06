# Main continuous-exposure DID specifications for the restricted research panel.
source('code/00_functions.R')
restricted_file <- 'db/final_merged_dataset.RData'
if (!file.exists(restricted_file)) {
  stop('The confidential provincial tax panel is not distributed. Run 02_synthetic_demo.R to inspect an illustrative workflow.')
}
db <- load_rdata_panel(restricted_file, preferred='final_merged_utf8_merge')
required <- c('COD_PROV', 'year', 'tax_gap_sh', 'redditti_provincia_autono',
              'self_empl_sh', 'prof3_oth_noncogn_sk_high', 'prof3_basic_sk_high',
              'prof3_cogn_sk_high', 'prof3_horizontal_sk_high', 'prof3_soft_sk_high')
if (length(missing <- setdiff(required, names(db)))) {
  stop('Missing original panel variables: ', paste(missing, collapse=', '))
}
db$dummy_policy <- as.integer(db$year >= 2008)

# Published working-code preparation: GDP-adjusted tax gap.
national_income <- c(1270962,1287529,1308328,1326675,1346539,1398284,1422063,
                     1426716,1427460,1450270,1462478,1490923,1514368,1501603,
                     1418573,1443247,1451697,1416148,1394602,1391953,1400297)
years <- 1995:2015
db$national_income <- national_income[match(db$year, years)]
db$outcome_tax_gap_sh <- (db$national_income / 1450270) * db$tax_gap_sh

# Pre-policy exposure fixed at its provincial 2007 value.
exposures <- c('redditti_provincia_autono', 'self_empl_sh',
               'prof3_oth_noncogn_sk_high', 'prof3_basic_sk_high',
               'prof3_cogn_sk_high', 'prof3_horizontal_sk_high', 'prof3_soft_sk_high')
pre <- db[db$year == 2007, c('COD_PROV', exposures), drop=FALSE]
pre <- pre[!duplicated(pre$COD_PROV), , drop=FALSE]
names(pre)[-1] <- paste0(exposures, '_baseline')
db <- merge(db, pre, by='COD_PROV', all.x=TRUE, sort=FALSE)
ref_income <- db$redditti_provincia_autono_baseline
low_exposure <- as.integer(ref_income <= stats::median(ref_income, na.rm=TRUE))
active <- db$dummy_policy * low_exposure

# Treatment names are those in the first-sheet author metadata.
db$trattamento_redditi_autonomi <- active * log(pmax(ref_income, .Machine$double.eps))
db$self_empl_sh_treat <- active * db$self_empl_sh_baseline
for (name in exposures[3:length(exposures)]) {
  db[[paste0(name, '_treat')]] <- active * db[[paste0(name,'_baseline')]]
}
models <- run_twfe_specs(db, 'code/meta_amedeo.xlsx',id='COD_PROV',time='year')
