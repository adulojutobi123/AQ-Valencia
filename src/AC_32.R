### Calidad del Aire en Comunitat Valenciana
### 14/05/2019 La Plata, Argentina
### Sol Represa
### Archivo 32

# Continuacion de AC_31
# Objetivo RF para AOD de MERRA a MAIAC

library(caret)
library(doParallel)

tabla <- read.csv("MAIAC_MERRA_pixel_diarios.csv")


# 1) Evaluar correlacion
cor.test(tabla$MAIAC, tabla$MERRA)
# cor = 0.55, t = 3442.1, df = 27305000, p-value < 2.2e-16


# 2) Ver grafico
png("MAIAC-MERRA.png")
plot(tabla$MAIAC,tabla$MERRA )
dev.off()


# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# 2. Generar set de prueba  #####

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

set.seed(123) #seteamos para obtener resultados reproducibles

tabla <- tabla[complete.cases(tabla),]
i_entrena <- createDataPartition(y = tabla$MAIAC, 
                                 p = 0.8, 
                                 list = FALSE)
entrena <- tabla[i_entrena,]
test <- tabla[-i_entrena,]


rm(i_entrena)



# 3) Modelo de regresión lineal
set.seed(123)
model <- lm(MAIAC ~ MERRA, data = entrena )
summary(model)

# Coefficients:
#  Estimate Std. Error t value Pr(>|t|)    
#  (Intercept) 0.0514580  0.0000201    2560   <2e-16 ***
#  MERRA       0.4359077  0.0001415    3080   <2e-16 ***

#  Residual standard error: 0.05938 on 21843615 degrees of freedom
#  Adjusted R-squared:  0.3028
#  F-statistic: 9.486e+06 on 1 and 21843615 DF,  p-value: < 2.2e-16

saveRDS(model, file = "MAIAC_MERRA_RL.rds")


# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# 7. Random Forest ####

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 


# Paralelizar proceso (con doParallel)

cl <- makePSOCKcluster(4)
registerDoParallel(cl) #registro del proceso paralelo


# Random forest con 10 fold cv - library(caret) 
train.control <- trainControl(method = "repeatedcv", 
                              number = 10,
                              repeats = 10,
                              search = "random") # Set up repeated k-fold cross-validation

model_rf <- train(MAIAC ~ MERRA + x + y, 
                  data = entrena,
                  method = 'rf', 
                  trControl = train.control,
                  ntree = 500,
                  importance = TRUE)

stopCluster(cl) #cerrar


saveRDS(model_rf, file = "MAIAC_MAIAC_rf_100tree.rds")

# mtry  RMSE      Rsquared   MAE      
# 7    2.440691  0.8928053  0.7642050

plot(varImp(model_rf))
plot(model_rf)


pred_rf <- predict(model_rf, test)

my_data <-  as.data.frame(cbind(predicted = pred_rf,
                                observed = test$MAIAC,
                                Error = abs(pred_rf - test$MAIAC)))

ggplot(my_data, aes(predicted, observed, colour = Error)) +
  geom_point(alpha = 0.8) + 
  geom_smooth(method = lm)+ ggtitle('Linear Regression ') +
  ggtitle("Random Forest: ntree = 10, mtry = 7") +
  xlab("Predicted") +
  ylab("Observed") +
  theme(plot.title = element_text(size = 18, hjust = 0.5),
        axis.text.y = element_text(size = 12),
        axis.text.x = element_text(size = 12, hjust=.5),
        axis.title.x = element_text(size = 14),
        axis.title.y = element_text(size = 14)) + 
  theme_bw() +
  #coord_fixed() +
  scale_colour_gradientn(colours = matlab.like(10))
