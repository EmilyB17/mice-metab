
## Aqueous metabolite ANOVAs on tumor and plasma tissue

# ---- getData ----

require(tidyverse)

# define standard error function
se <- function(x) sqrt(var(x)/length(x))

dat <- read.table("https://raw.githubusercontent.com/EmilyB17/mice-metab/master/data/cleanedNamesAqueous.txt", sep = "\t", header = TRUE) %>% 
  # hyphenate instead of _ for treatment ID
  mutate(treatmentID = str_replace_all(treatmentID, "_", "-"))

# set ggplot theme 
theme_set(theme_classic())

# get colors
#source("./R/RColorBrewer.R")

## ---- tumor ----

# get the average of each SED+AL metabolite

sedal <- dat %>% 
  # get only tumor
  filter(str_detect(id, "_tumor")) %>% 
  # get only SED_AL
  filter(treatmentID == "SED+AL") %>% 
  group_by(Metabolite) %>% 
  # average
  summarize(avgSedAl = mean(area),
            seSedAl = se(area))

# get change compared to SED+AL
abdat <- dat %>% 
  filter(str_detect(id, "_tumor")) %>% 
  left_join(sedal, by = "Metabolite") %>% 
  # calculate change
  mutate(ab.change = area - avgSedAl) %>% 
  # SED+AL is now 0
  mutate(ab.change = case_when(
    treatmentID %in% "SED+AL" ~ 0,
    treatmentID != "SED+AL" ~ ab.change
  ))%>% 
  select(id, treatmentID, Metabolite, ab.change) 

# perform ANOVA between treatment groups
metabs <- unique(abdat$Metabolite)
pvals <- data.frame()

for(i in 1:length(metabs)) {
  
  # define model
  mod <- aov(ab.change ~ treatmentID, data = filter(abdat, Metabolite == metabs[i]))
  
  # do Tukey posthoc
  tukey <- TukeyHSD(mod)
  
  # get p vals
  ps <- data.frame(Metabolite = metabs[i],
                   contrast = rownames(tukey[1]$treatmentID),
                   pval = round(tukey[1]$treatmentID[,4], 3),
                   Fstat = round(summary(mod)[[1]][1,4], 2),
                   row.names = NULL)
  
  # concatenate
  pvals <- rbind(pvals, ps)
  
}

# get significant 
sigs <- pvals %>% 
  filter(pval < 0.05)

# get table of mean +/- SE for results section
df <- abdat %>% 
  semi_join(sigs, by = "Metabolite") %>% 
  group_by(treatmentID, Metabolite) %>% 
  summarize(avgchange = round(mean(ab.change), 3),
            sechange = round(se(ab.change), 3)) %>% 
  pivot_wider(names_from = treatmentID, values_from = c(avgchange, sechange))

# write to table
#write.table(df, "./data/changefromSEDAL-tumor-ANOVA.txt", sep = "\t", row.names = FALSE)

# get only PA+ER vs SED+AL for Results section
paer <- sigs %>% filter(contrast == "SED+AL-PA+ER")


# for manuscript: need number of replicates (mice) in each treatment
reps <- abdat %>% 
  filter(str_detect(id, "_tumor")) %>% 
  group_by(treatmentID) %>% 
  summarize(reps = length(unique(id)))


## ---- plasma ----

# get only plasma and calculate Time column
plasma <- dat %>% 
  filter(str_detect(id, "_plasma")) %>% 
  # make Time column
  mutate(Time = case_when(
    str_detect(id, "_plasmaD7") ~ "Day 7",
    str_detect(id, "_plasmaD21") ~ "Day 21",
    str_detect(id, "_plasmaD35") ~ "Day 35"
  ))

# get the average of each SED+AL metabolite

sedal <- plasma %>% 
  # get only SED_AL
  filter(treatmentID == "SED+AL") %>% 
  group_by(Metabolite) %>% 
  # average
  summarize(avgSedAl = mean(area),
            seSedAl = se(area))

# get change compared to SED+AL
abdat <- plasma %>% 
  left_join(sedal, by = "Metabolite") %>% 
  # calculate change
  mutate(ab.change = area - avgSedAl) %>% 
  # SED+AL is now 0
  mutate(ab.change = case_when(
    treatmentID %in% "SED+AL" ~ 0,
    treatmentID != "SED+AL" ~ ab.change
  ))%>% 
  select(id, treatmentID, Time, Metabolite, ab.change) 

# get number of mice in each group
reps <- abdat %>% 
  group_by(treatmentID, Time) %>% 
  summarize(rep = length(unique(id)))

### 1. ANOVA WITHIN D35 (are there metabolic changes at the end of tumor progression?)

# get only d35
d35 <- abdat %>% 
  filter(Time == "Day 35") %>% 
  mutate(treatmentID = factor(treatmentID))

# do model loop
metabs <- unique(d35$Metabolite)
pvals <- data.frame()

for(i in 1:length(metabs)) {
  
  # define model
  mod <- aov(ab.change ~ treatmentID, data = filter(d35, Metabolite == metabs[i]))
  
  # do Tukey posthoc
  tukey <- TukeyHSD(mod)
  
  # get p vals
  ps <- data.frame(Metabolite = metabs[i],
                   contrast = rownames(tukey[1]$treatmentID),
                   pval = tukey[1]$treatmentID[,4],
                   Fstat = round(summary(mod)[[1]][1,4], 2),
                   row.names = NULL)
  
  # concatenate
  pvals <- rbind(pvals, ps)
  
}

# get significant 
sigs <- pvals %>% 
  filter(pval < 0.05)

# get only PA+ER vs SED+AL
paer <- sigs %>% filter(contrast == "SED+AL-PA+ER")  # only Xanthosine

# get table of mean +/- SE for results section
df <- d35 %>% 
  semi_join(sigs, by = "Metabolite") %>% 
  group_by(treatmentID, Metabolite) %>% 
  summarize(avgchange = round(mean(ab.change), 3),
            sechange = round(se(ab.change), 3)) %>% 
  pivot_wider(names_from = treatmentID, values_from = c(avgchange, sechange))

# write to table
#write.table(df, "./data/changefromSEDAL-plasma-d35-ANOVA.txt", sep = "\t", row.names = FALSE)

# for the manuscript: need the number of replicates shown in each group
reps <- plotdat %>% 
  group_by(treatmentID, Metabolite) %>% 
  summarize(rep = length(unique(id)))


### 2. Each metabolite over time (within treatments) 

# get unique metabolites and treatments
trt <- unique(abdat$treatmentID)
mets <- unique(abdat$Metabolite)

pvals <- data.frame()

for(j in 1:length(trt)) {
  
  for(i in 1:length(mets)) {
    
    # define model
    mod <- aov(ab.change ~ Time, data = filter(abdat, treatmentID == trt[j] & Metabolite == mets[i]))
    
    # do Tukey posthoc
    tukey <- TukeyHSD(mod)
    
    # get p vals
    ps <- data.frame(Metabolite = mets[i],
                     treatmentID = trt[j],
                     contrast = rownames(tukey[1]$Time),
                     pval = round(tukey[1]$Time[,4], 3),
                     Fstat = round(summary(mod)[[1]][1,4], 2),
                     row.names = NULL)
    
    # concatenate
    pvals <- rbind(pvals, ps)
  }
}

# get significant 
sigs <- pvals %>% 
  filter(pval < 0.05)

# get only PA+ER
paer <- sigs %>% filter(treatmentID == "PA+ER")

### 2a. Treatments between start & end (Day 7 vs Day 35)

# remove Day 21
tdat <- abdat %>% filter(!Time == "Day 21")

# get unique metabolites and treatments
trt <- unique(tdat$treatmentID)
mets <- unique(tdat$Metabolite)

pvals <- data.frame()

for(j in 1:length(trt)) {
  
  for(i in 1:length(mets)) {
    
    # define model
    mod <- t.test(ab.change ~ Time, data = filter(tdat, treatmentID == trt[j] & Metabolite == mets[i]))
    
    # get p vals
    ps <- data.frame(Metabolite = mets[i],
                     treatmentID = trt[j],
                     pval = round(mod$p.value, 3),
                     tstat = round(mod$statistic, 3),
                     row.names = NULL)
    
    # concatenate
    pvals <- rbind(pvals, ps)
  }
}

# get significant 
sigs <- pvals %>% 
  drop_na() %>% 
  filter(pval < 0.05)

# get only PA+ER
paer <- sigs %>% filter(treatmentID == "PA+ER")


# get table of mean +/- SE for results section
df <- abdat %>% 
  semi_join(sigs, by = "Metabolite") %>% 
  group_by(treatmentID, Metabolite, Time) %>% 
  summarize(avgchange = round(mean(ab.change), 3),
            sechange = round(se(ab.change), 3)) %>% 
  pivot_wider(names_from = c(treatmentID, Time), values_from = c(avgchange, sechange))

# write to table
#write.table(df, "./data/changefromSEDAL-plasma-Time-ANOVA.txt", sep = "\t", row.names = FALSE)

# separate each treatment for writing to table (it's too big as-is)
t1 <- abdat %>% 
  semi_join(filter(sigs, treatmentID == "PA+ER"), by = "Metabolite") %>% 
  filter(treatmentID == "PA+ER") %>% 
  group_by(Metabolite, Time) %>% 
  summarize(avgchange = round(mean(ab.change), 3),
            sechange = round(se(ab.change), 3)) %>% 
  pivot_wider(names_from = Time, values_from = c(avgchange, sechange))

# write to table
#write.table(t1, "./data/changefromSEDAL-plasma-Time-PA+ER-ANOVA.txt", sep = "\t", row.names = FALSE)

t2 <- abdat %>% 
  semi_join(filter(sigs, treatmentID == "PA+AL"), by = "Metabolite") %>% 
  filter(treatmentID == "PA+AL") %>% 
  group_by(Metabolite, Time) %>% 
  summarize(avgchange = round(mean(ab.change), 3),
            sechange = round(se(ab.change), 3)) %>% 
  pivot_wider(names_from = Time, values_from = c(avgchange, sechange))

# write to table
#write.table(t2, "./data/changefromSEDAL-plasma-Time-PA+AL-ANOVA.txt", sep = "\t", row.names = FALSE)

t3 <- abdat %>% 
  semi_join(filter(sigs, treatmentID == "SED+ER"), by = "Metabolite") %>% 
  filter(treatmentID == "SED+ER") %>% 
  group_by(Metabolite, Time) %>% 
  summarize(avgchange = round(mean(ab.change), 3),
            sechange = round(se(ab.change), 3)) %>% 
  pivot_wider(names_from = Time, values_from = c(avgchange, sechange))

# write to table
#write.table(t3, "./data/changefromSEDAL-plasma-Time-SED+ER-ANOVA.txt", sep = "\t", row.names = FALSE)






### PLOT ---- plot all significant 
plotdat <- abdat %>% 
  semi_join(sigs, by = "Metabolite") %>% 
  filter(!treatmentID == "SED+AL") %>% 
  group_by(treatmentID, Metabolite, Time) %>% 
  summarize(avg = mean(ab.change),
            se = se(ab.change)) %>% 
  ungroup() %>% 
  mutate(Time = factor(Time, ordered = TRUE, levels = c("Day 7", "Day 21", "Day 35")),
         treatmentID = factor(treatmentID, ordered = TRUE, levels = c("PA+AL", "SED+ER", "PA+ER")))


# set conditional term for errorbars (thanks, Google)
limits <- aes(
  ymax = avg + (avg > 0)*se,  
  ymin = avg - (avg < 0)*se)


# create the plots in a loop
met <- unique(plotdat$Metabolite)

for(i in 1:length(met)) {
  
  # make plot
  plot <- ggplot(data = filter(plotdat, Metabolite == met[i]), aes(x = Time, y = avg, fill = treatmentID)) +
    geom_bar(stat = "identity", position = position_dodge(0.95), color = "black") +
    geom_errorbar(limits, position = position_dodge(0.95), width = 0.6) +
    scale_fill_manual(values = treatmentGreys) +
    labs(x = "Time", y = "Change from SED+AL", fill = "Treatment", title = met[i])
  
  # save 
  ggsave(filename = paste0("./data/plots/indiv-barplots-plasma-ANOVA-", as.character(met[i]), ".png"), plot = plot, dpi = 600, height = 4.35, width = 7.32, units = "in")
  
  # print progress
  cat(as.character(met[i]))
}
