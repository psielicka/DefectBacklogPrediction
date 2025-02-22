arima_prediction <- function(product, training_history, number_of_weeks_to_predict){
    
defect_backlog = read.csv(file=paste("data/", product[1], "/", product[2], "/", product[1], "_", product[2], "_backlog.csv", sep=""), header=TRUE, sep=",")
weeks_to_predict = read.csv(file=paste("data/", product[1], "/", product[2], "/", product[1], "_", product[2], "_samples.csv", sep=""), header=FALSE, sep=",")
    
weekly_backlog_ts = ts(defect_backlog$backlog_all)
models <- c()
last_week_number = tail(defect_backlog$number, n=1)

for(j in 1:number_of_weeks_to_predict){
    assign(paste('forecast', j, sep='_'), c())
    assign(paste('actual', j, sep='_'), c())
    assign(paste('error', j, sep='_'), c())
}

for(i in 1:nrow(weeks_to_predict)){
    week_number <- weeks_to_predict[i,1]
    if ((week_number-training_history)<0 | (training_history == 0 & week_number == 0)){
        models[i] = NA
        for(j in 1:number_of_weeks_to_predict){
            forecasts_j = get(paste("forecast", j, sep = "_"))
            assign(paste('forecast', j, sep='_'), c(forecasts_j, NA))

            actual_backlog_size = (defect_backlog %>% filter (number == (week_number + j -1)) %>% select (backlog_all))[[1]]
            actuals_j = get(paste("actual", j, sep = "_"))
            assign(paste('actual', j, sep='_'), c(actuals_j, actual_backlog_size))

            errors_j = get(paste("error", j, sep = "_"))
            assign(paste('error', j, sep='_'), c(errors_j, NA ))
        }
    } else {
        # if training_history = 0 then all past data are used as a training history
        training_start_week = ifelse(training_history == 0, 0, week_number - training_history)
        fit = auto.arima(subset(weekly_backlog_ts, 
                               start = training_start_week,
                               end = week_number))
        fc = forecast(fit, number_of_weeks_to_predict)
#         p = length(fit$model$phi)
#         d = fit$model$Delta
#         q = length(fit$model$theta)
        arma = fit$arma
        models[i] = paste(arma[1], arma[6], arma[2])
        for(j in 1:number_of_weeks_to_predict){
            forecasted_value = round(fc$mean[j])
            forecasts_j = get(paste("forecast", j, sep = "_"))
            assign(paste('forecast', j, sep='_'), c(forecasts_j, forecasted_value))

            if(week_number + j -1 <= last_week_number){
                actual_backlog_size = (defect_backlog %>% filter (number == (week_number + j -1)) %>% select (backlog_all))[[1]]
                actuals_j = get(paste("actual", j, sep = "_"))
                assign(paste('actual', j, sep='_'), c(actuals_j, actual_backlog_size))

                ae = abs(forecasted_value - actual_backlog_size)
                errors_j = get(paste("error", j, sep = "_"))
                assign(paste('error', j, sep='_'), c(errors_j, ae ))
            } else {
                actuals_j = get(paste("actual", j, sep = "_"))
                assign(paste('actual', j, sep='_'), c(actuals_j, NA))

                errors_j = get(paste("error", j, sep = "_"))
                assign(paste('error', j, sep='_'), c(errors_j, NA ))
            }
        }
    }
}

result <- data.frame(Week = weeks_to_predict,
                      p_d_g = models)
    
for(j in 1:number_of_weeks_to_predict){
    forecasts_j = get(paste("forecast", j, sep = "_"))
    actuals_j = get(paste("actual", j, sep = "_"))
    errors_j = get(paste("error", j, sep = "_"))
    results_j = data.frame(Week = weeks_to_predict)

    results_j[, paste("Actual", j, sep="_")] = actuals_j
    results_j[, paste("Forecast", j, sep="_")] = forecasts_j
    results_j[, paste("Error", j, sep="_")] = errors_j
    
    result <- merge(result, results_j, all = TRUE)
} 
colnames(result)[1] <- "Week"

th <- ifelse(training_history == 0, "all", training_history)
result_file_path = paste("data/", product[1], "/", product[2], "/Predictions/", "arima_th:", th, ".csv", sep="")
write.table(result, file = result_file_path, sep=",")
}