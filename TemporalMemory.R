
library(tidyverse); library(ggbeeswarm); library(lmerTest); library(janitor); library(here); library(psych); library(pwr); library(tidyr); library(stringr); library(sjPlot); library(cocor)
theme_Publication <- function(base_size=18, base_family="Helvetica") {
  library(grid); library(ggthemes)
  (theme_foundation(base_size=base_size, base_family=base_family)
    + theme(plot.title = element_text(face = "bold",size = rel(1.2), hjust = 0.5),
            text = element_text(),panel.background = element_rect(colour = NA), plot.background =
              element_rect(colour = NA),
            panel.border = element_rect(colour = NA),axis.title = element_text(face = "bold",size = rel(1)),
            axis.title.y = element_text(angle=90,vjust =2),axis.title.x = element_text(vjust = -0.2),
            axis.text = element_text(), axis.line = element_line(colour="black"),axis.ticks = element_line(),
            panel.grid.major = element_blank(),panel.grid.minor = element_blank(),
            legend.position = "right", legend.direction = "vertical", legend.key.size= unit(0.8, "cm"),
            legend.title = element_text(face="bold", size = rel(0.8)), legend.key = element_rect(colour = NA), 
            plot.margin=unit(c(10,5,5,5),"mm"),
            strip.background=element_rect(colour="#f0f0f0",fill="#f0f0f0"),strip.text = element_text(face="bold")))
}

#pvalue function
format_p <- function(pval){
  if(pval < 0.001){"< .001"} else if(pval < 0.009){str_remove(round(pval,3), "^0+")} else {str_remove(round(pval,2), "^0+")}
}
# Now read in the cleaned version:
ASG_data <- read.csv("Exp1/ASG_data.csv")
TT_data <- read.csv("Exp1/TT_data.csv")
participant_data <- read.csv("Exp1/participant_data.csv")

# Putting things into long format and making some tables for stats and graphs
# For the Memory Task:
ASG_data_clean <- ASG_data %>%
  pivot_longer(q1:q18, names_to="Q", values_to="corr") %>%
  mutate(Q_type = case_when(
    Q=="q1"|Q=="q2"|Q=="q3"|Q=="q7"|Q=="q8"|Q=="q9"|Q=="q13"|Q=="q14"|Q=="q15" ~ "location",
    Q=="q4"|Q=="q5"|Q=="q6"|Q=="q10"|Q=="q11"|Q=="q12"|Q=="q16"|Q=="q17"|Q=="q18" ~ "temporal"))

# Changing some data types so that the data looks and operates like we intend to:
ASG_data_clean$corr <- as.numeric(as.character(ASG_data_clean$corr))
ASG_data_clean$Q <- as.factor(ASG_data_clean$Q)
ASG_data_clean <- na.omit(ASG_data_clean)

# Accuracy by question type:
# 1. group-level data: overall when/where performance
mem_acc_group <- ASG_data_clean %>%
  group_by(Q_type) %>% 
  summarise(acc = mean(corr), se = sd(corr)/sqrt(n())) %>%
  mutate(se_lo = acc - se,
         se_hi = acc + se)

# 2. subject-level data: individual when/where performance
mem_acc_sub <- ASG_data_clean %>%
  group_by(Participant_ID, Q_type) %>% 
  summarise(acc = mean(corr))

# Timeline Task
TT_data_clean <- TT_data %>%
  mutate(lines = as.factor(case_when(num_lines==0 ~ "no lines", num_lines ==1|num_lines ==2 ~ "at least one line")))

# Types of line arrangements:
# Cleaning the data so that we can name the line types for both day and time trials.
TT_data_clean = TT_data_clean %>%
  pivot_longer(2:3, names_to="trial_type", values_to="line_type") %>%
  mutate(line_type = as.factor(case_when(
    line_type==1 ~ "Left-to-Right", line_type==2 ~ "Right-to-Left", line_type==3 ~ "Top-to-Bottom", line_type==4 ~ "Bottom-to-Top", line_type==5 ~ "Diagonal",line_type==6 ~ "Nonlinear")))

TT_data_clean$line_type <- factor(TT_data_clean$line_type, levels = c("Left-to-Right", "Right-to-Left", "Top-to-Bottom", "Bottom-to-Top", "Diagonal", "Nonlinear"))
TT_data_clean$Participant_ID <- as.character(TT_data_clean$Participant_ID)

# Making a dataframe that has the line types and total number of lines
timeline.df <- TT_data_clean %>%
  group_by(line_type, num_lines) %>%
  summarise(line_count = length(line_type))

# Dataframe that just total number of lines across two trials
numline_prop <- TT_data %>%
  group_by(num_lines) %>%
  summarise(line_count = length(num_lines)) %>%
  rowwise() %>%
  mutate(prop_lines = line_count/length(unique(TT_data$Participant_ID)))

# Overall proportion of linear responses across all trials across all participants
linear_prop = TT_data_clean %>%
  summarize(tot_trials = length(line_type), tot_lines = sum(ifelse(line_type == "Nonlinear",0,1))) %>%
  rowwise() %>%
  mutate(prop_lines = tot_lines/tot_trials) #about 40% of all responses were nonlinear

# Dataframe to look at total LR lines made for all kids
lr_all <- TT_data %>%
  mutate(LR_DL = ifelse(TT_data$`DL` == 1, 1, 0),
         LR_TL = ifelse(TT_data$`TL` == 1, 1, 0),
         LR_tot = LR_DL + LR_TL)
lr_all <- lr_all[, -c(2:3)]
lr_all <- merge(lr_all, ASG_data_clean, by = "Participant_ID")

# LR lines only in kids who made at least one line
lr_lines <- subset(lr_all, num_lines != 0)
lr_lines$LR_tot <- as.numeric(lr_lines$LR_tot)
lr_lines$num_lines<- as.numeric(lr_lines$num_lines)

# Merging clean memory data with number of lines:
line_info <- select(TT_data, Participant_ID, num_lines)
all_data <- merge(ASG_data_clean, line_info, by = "Participant_ID")

# Combining subject-level memory accuracy with number of lines made
lines_TT <- merge(TT_data_clean, mem_acc_sub, all = T)
lines_TT <- na.omit(lines_TT) #to get rid of participants who didn't do 

# Memory accuracy for both question types, grouped by number of lines:
mem_acc_lines <- lines_TT %>%
  group_by(num_lines, Q_type) %>%
  summarise(corr =mean(acc), se = sd(acc)/sqrt(n())) %>%
  mutate(se_lo = corr - se,
         se_hi = corr + se) %>%
  mutate(Q_type =  factor(Q_type),
         num_lines = factor(num_lines))

# Individual accuracy for each question, grouped by number of lines:
mem_acc_lines_sub <- lines_TT %>%
  group_by(Participant_ID,num_lines, Q_type) %>%
  summarise(corr =mean(acc)) %>%
  mutate(num_lines = factor(num_lines)) %>%
  mutate(Q_type =  factor(Q_type))
```

```{r memory task stats, echo=FALSE, include=FALSE}
knitr::opts_chunk$set(warning = FALSE, message = FALSE)
#Memory Task
#1. Model to see whether location questions easier than temporal order questions
ACC_Qtype <- glmer(corr~Q_type + (Q_type| Participant_ID), family = binomial(link = "logit"), data = ASG_data_clean)
summary(ACC_Qtype) 
RefACC_Qtype <-summary(ACC_Qtype) 

#Age and Memory Correlations
#2. Age correlation with overall memory performance
age_cont <- select(participant_data, c("Participant_ID", "Age"))
age_corr <- merge(mem_acc_sub, age_cont, by = "Participant_ID")

#separated by question type
age_corr_Q <- age_corr %>%
  group_by(Participant_ID, Age, Q_type)

#averaged across question type
age_corr <- age_corr %>%
  group_by(Participant_ID, Age) %>%
  summarize(acc = mean(acc))

ref_mem_corr <- cor.test(age_corr$Age, age_corr$acc, method = "pearson")

#Age correlation with temporal memory performance
t_participants <- age_corr_Q %>% subset(age_corr_Q$Q_type == "temporal")
ref_tem_corr <- cor.test(t_participants$Age, t_participants$acc, method = "pearson")

#Age correlation with location memory performance
l_participants <- age_corr_Q %>% subset(age_corr_Q$Q_type == "location") 
ref_loc_corr <- cor.test(l_participants$Age, l_participants$acc, method = "pearson")

#subject-level correlation of accuracy in two trial types
t_participants <- mem_acc_sub %>% subset(mem_acc_sub$Q_type == "temporal")
l_participants <- mem_acc_sub %>% subset(mem_acc_sub$Q_type == "location")
ref_qtype_corr <- cor.test(t_participants$acc, l_participants$acc, method = "pearson")

#compare correlation coefficients
comparison_corr <- cocor.dep.groups.overlap(r.jk=+ref_tem_corr$estimate, r.jh=+ref_loc_corr$estimate, r.kh=+ref_qtype_corr$estimate, n=96, alternative="two.sided", alpha=0.05, conf.level=0.95, null.value=0)

# Instead of looking at individuals, look at overall proportion of lines and LR lines
#Long format of line types
tt_long = TT_data %>%
  pivot_longer(cols = `DL`:`TL`, names_to = "trial", values_to = "line_type") %>%
  mutate(is_line = ifelse(line_type==6, 0, 1), is_LR = ifelse(line_type==1, 1,0)) %>%
  mutate(line_type = as.factor(case_when(
    line_type==1 ~ "Left-to-Right", line_type==2 ~ "Right-to-Left", line_type==3 ~ "Top-to-Bottom", line_type==4 ~ "Bottom-to-Top", line_type==5 ~ "Diagonal",line_type==6 ~ "Nonlinear")))

tt_long$line_type <- factor(TT_data_clean$line_type, levels = c("Left-to-Right", "Right-to-Left", "Top-to-Bottom", "Bottom-to-Top", "Diagonal", "Nonlinear"))

#Does age have an influence on total number of lines made?
#Age correlation with number of lines made
age_lines <- merge(age_cont, TT_data, by = "Participant_ID")
age_lines <- select(age_lines, c("Age", "num_lines"))
age_lines_corr <- cor.test(age_lines$Age, age_lines$num_lines, method = "spearman")

#Does age have an influence on total number of left to right lines made?
#Age correlation with number of left to right lines made
lr_cor <- merge(age_cont, lr_all, by ="Participant_ID") %>%
  group_by(Participant_ID, Age) %>%
  summarise(LR_tot = first(LR_tot))

age_lr_corr <- cor.test(lr_cor$Age, lr_cor$LR_tot, method = "spearman")

#Does trial type have an influence on total number of lines made?
#Linear arrangements, and line orientations by trial type ("different days" vs "times of day" trials)
#Chi-sq tests:
#For total number lines made:
trial_all = tt_long %>%
  group_by(trial) %>%
  summarize(tot_trials = length(is_line), tot_lines = sum(is_line))

#frequency of each orientation by line type
trialTT.df <- tt_long %>%
  group_by(trial, line_type) %>%
  summarize(n_type = length(line_type))

trialTT.df <- merge(trialTT.df, trial_all)

#proportions of line types
trialTT.df <- trialTT.df %>%
  rowwise() %>%
  mutate(prop_lines = tot_lines/tot_trials, prop_type = ifelse(line_type=="Nonlinear", n_type/tot_trials, n_type/tot_lines))

#without grouping by trial type
TT.df <- tt_long %>%
  group_by(line_type) %>%
  summarize(n_type = length(line_type))

TT.df <-subset(TT.df, TT.df$line_type != "Nonlinear") %>%
  mutate(prop_type = n_type/sum(n_type))

#Chi square analysis
#for total lines made:
DL <- c((trialTT.df$tot_trials[1]-trialTT.df$tot_lines[1]), trialTT.df$tot_lines[1])  # Number of responses in DL (trials-lines, lines)
TL <- c((trialTT.df$tot_trials[7]-trialTT.df$tot_lines[7]), trialTT.df$tot_lines[7])  # Number of responses in TL (trials-lines, lines)

#Create a matrix with the contingency table
lines_trial <- matrix(c(DL, TL), nrow = 2, byrow = TRUE)
rownames(lines_trial) <- c("DL","TL")
colnames(lines_trial) <- c("trials-lines", "lines")
triallines_chi <- chisq.test(lines_trial)
triallines_chi

#for only the LR lines made (within linear arrangmements)
DL <- c((trialTT.df$tot_lines[1]-trialTT.df$n_type[1]), trialTT.df$tot_lines[1])  # Number of responses in DL (lines- LR lines, lines)
TL <- c((trialTT.df$tot_lines[7]-trialTT.df$n_type[7]), trialTT.df$tot_lines[7]) # Number of responses in TL (lines-LR lines, lines)

#Create a matrix with the contingency table
lr_lines_trial <- matrix(c(DL, TL), nrow = 2, byrow = TRUE)
rownames(lr_lines_trial) <- c("DL","TL")
colnames(lr_lines_trial) <- c("linear trials-LR lines", "LR lines")
lr_triallines_chi <- chisq.test(lr_lines_trial)
lr_triallines_chi

#Timeline Task
#frequency of the different orientations of sticker arrangements 
#Chi-sq tests:
#distribution for kids who made 1 line
oneline_distr <- subset(timeline.df, num_lines ==1)
oneline_distr <- oneline_distr[c(1,3)]
oneline_distr <- subset(oneline_distr, line_type != "Nonlinear")

oneline_distr <- oneline_distr %>%
  ungroup()%>%
  mutate(totaln = sum(line_count))

f1 <- oneline_distr$line_count
onechi <- chisq.test(f1) 
onechi

#distribution for kids who made 2 lines
twolines_distr <- subset(timeline.df, num_lines ==2)
twolines_distr <- twolines_distr[c(1,3)]

twolines_distr <- twolines_distr %>%
  ungroup()%>%
  mutate(totaln = sum(line_count))

f2 <- twolines_distr$line_count
twochi <- chisq.test(f2) 
twochi

#distribution of number of lines made across all participants
#participants are predominantly making two linear arrangements across the two trials
num_lines_distr <- TT_data %>%
  group_by(num_lines) %>%
  summarise(count = length(num_lines))

f3 <- num_lines_distr$count
allchi <- chisq.test(f3)
allchi
#Looking at internal consistency among children:
#Only children who made 2 lines could have had line arrangements consistent across the two trials
consistent_lines <- subset(TT_data, TT_data$num_lines ==2)
inconsistent_lines <- subset(consistent_lines, consistent_lines$`DL` != consistent_lines$`TL`)

#include if they made the same linear orientation for two trials
consistent_lines <- subset(consistent_lines, consistent_lines$`DL` == consistent_lines$`TL`)
#just need one of the columns now
consistent_lines <- select(consistent_lines, c(Participant_ID, DL))
#rename
colnames(consistent_lines) <- c("Participant_ID", "line_type")
#as factor
consistent_lines = consistent_lines %>%
  mutate(line_type = as.factor(case_when(
    line_type==1 ~ "Left-to-Right", line_type==2 ~ "Right-to-Left", line_type==3 ~ "Top-to-Bottom", line_type==4 ~ "Bottom-to-Top", line_type==5 ~ "Diagonal",line_type==6 ~ "Nonlinear")))

#summarize the line orientations of consistent linear orientations
consistent_lines <- consistent_lines %>%
  group_by(line_type) %>%
  summarise(line_count = length(line_type))

#total number of kids who made the same line across the two trials
num_consistent <- sum(consistent_lines$line_count) 
#proportion of kids who made the same line across the two trials, among children who made 2 lines
prop_consistent <- num_consistent /numline_prop$line_count[3]*100

#total number of kids who made a left to right line across the two trials
num_consistent_lr <- consistent_lines$line_count[3]
prop_lr_consistent <- num_consistent_lr/length(unique(ASG_data$Participant_ID))*100

#1. Memory and Timeline Interaction:
ACC_Qtype_Lines <- glmer(corr~Q_type * num_lines + (Q_type | Participant_ID), family = binomial(link = "logit"), control=glmerControl(optimizer="bobyqa"), data = all_data)
summary(ACC_Qtype_Lines)
RefACC_Qtype_Lines <- summary(ACC_Qtype_Lines)

#2. Looking at number of left-to-right lines only in kids who made at least one line
ACC_LR_Lines <- glmer(corr~Q_type * LR_tot + (1|Participant_ID), family = binomial(link = "logit"),control=glmerControl(optimizer="bobyqa"),  data = lr_lines)
summary(ACC_LR_Lines)
RefACC_LR_Lines <- summary(ACC_LR_Lines)

#4. Memory and Timeline Interaction, controlling for age
all_data <- merge(all_data, age_cont, by = "Participant_ID") #add age information in the dataframe

Age_ACC_Lines <- glmer(corr ~ Q_type * num_lines + Age + (1 | Participant_ID), family = binomial(link = "logit"), control = glmerControl(optimizer = "bobyqa"), data = all_data)

summary(Age_ACC_Lines)
RefAge_ACC_Lines <- summary(Age_ACC_Lines)

#5. Binomial mixed effects models that control for age
#For temporal memory
temp_glmer <- all_data %>%
  filter(Q_type == "temporal" & num_lines != 1)
#model
temp_glmer = glmer(corr ~  num_lines + Age + (1 | Participant_ID), family = binomial(link = "logit"), control = glmerControl(optimizer = "bobyqa"), data = temp_glmer)
summary(temp_glmer)
reftemp_glmer <- summary(temp_glmer)
#For location memory
loc_glmer <- all_data %>%
  filter(Q_type == "location" & num_lines != 1)
#model
loc_glmer = glmer(corr ~  num_lines + Age + (1 | Participant_ID), family = binomial(link = "logit"), control = glmerControl(optimizer = "bobyqa"), data = loc_glmer)
summary(loc_glmer)
refloc_glmer <- summary(loc_glmer)

#6. Follow-up binomial mixed effect models looking at children's LR lines
#check participant numbers in the model outputs
lr_age <- merge(age_cont, lr_all, by ="Participant_ID")
#For temporal memory
temp_lr <- lr_age %>%
  filter(Q_type == "temporal" & num_lines != 0)
#model
tLR_glmer = glmer(corr ~ LR_tot + Age + (1 | Participant_ID), family = binomial(link = "logit"), control = glmerControl(optimizer = "bobyqa"), data = temp_lr)
summary(tLR_glmer)
reftemp_LR <- summary(tLR_glmer)

#For location memory
loc_lr <- lr_age %>%
  filter(Q_type == "location" & num_lines != 0)
#model
lLR_glmer = glmer(corr ~ LR_tot + Age + (1 | Participant_ID), family = binomial(link = "logit"), control = glmerControl(optimizer = "bobyqa"), data = loc_lr)
summary(lLR_glmer)
refloc_LR <- summary(lLR_glmer)

#Subject-level memory data by question type
ggplot(mem_acc_sub, aes(x = Q_type, y = acc, fill = Q_type)) +
  geom_boxplot(width = 0.5, outlier.colour = NA, alpha = 0.6, color="black", fill="blue") +
  geom_quasirandom(width = .15, size = 1, alpha = 1) +
  geom_errorbar(data=mem_acc_group, aes(ymin = se_lo, ymax = se_hi, y=NULL), width=0) + geom_hline(yintercept = 0.33, linetype = "dotted") +
  geom_point(data=mem_acc_group, aes(y = acc), fill='white', shape=23, size=3) +
  guides(fill = F) +
  xlab('Memory Question Type') +
  ylab('Accuracy') +
  theme_Publication()

#Timeline Task
#plotting line types by number of lines made
line_distr <- ggplot(timeline.df, aes(fill=line_type, y= line_count, x=num_lines)) +
  geom_bar(position="fill", stat="identity", colour="black") + xlab('Total Number of Lines') +ylab('Proportion of Response') +  theme_Publication() + scale_y_continuous(expand = expansion(mult = c(0, 0))) + labs(fill='Line Arrangement') + scale_fill_manual(values = c("#7294D4","#5BBCD6", "#00A08A","#EBCC2A", "#F98400", "#F21A00"))
line_distr