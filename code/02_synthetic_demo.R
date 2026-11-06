# Synthetic illustration only (not the published estimation)
panel <- read.csv('db/simulated_panel.csv')
panel$post <- as.integer(panel$year >= 2008)
pre <- panel[panel$year==2007,c('COD_PROV','redditti_provincia_autono')]
names(pre)[2] <- 'exposure_2007'
panel <- merge(panel,pre,by='COD_PROV',all.x=TRUE)
panel$did <- panel$post*panel$exposure_2007
if (!requireNamespace('plm',quietly=TRUE)) stop('Install plm.')
demo <- plm::plm(tax_gap ~ did + self_empl_sh, data=panel,
                 index=c('COD_PROV','year'),model='within',effect='twoways')
print(summary(demo))
