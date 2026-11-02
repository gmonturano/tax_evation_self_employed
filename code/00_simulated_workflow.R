# Simulated demonstrator only — NOT a reproduction of published tax-gap estimates
# Run from repository root. No external R packages needed.
db <- read.csv("db/simulated_panel.csv")
pre <- subset(db, year == 2007, select = c(COD_PROV, self_empl_sh))
names(pre)[2] <- "exposure_2007"
db <- merge(db, pre, by="COD_PROV", all.x=TRUE)
db$post_policy <- as.integer(db$year >= 2008)
fit <- lm(tax_gap ~ post_policy:exposure_2007 + factor(COD_PROV) + factor(year), data=db)
print(summary(fit))
message("Synthetic demonstration only: coefficients have no substantive interpretation")
