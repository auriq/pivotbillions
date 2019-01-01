runweekly <- function(wstart,wend,verbose=F,plot=F,tplot=F,model="",addtotitle="",levered=100000,unlevered=100000,override="",balance=20000,marginutilization=20,leverage=50,compounding=T,commissions=0.000036,d=NULL,weektoday=F,systemcommand="",metrics=T,legend=F,infnull=F,meanrate=1,udbthread=1,normalized=T,pippercent=100) {
  if (commissions!=0.000036) {
    print(paste0("USING COMMISSIONS OF ",commissions))
  }
  # print(paste0(wstart, ' to ', wend))
  if (compounding==T) {
    metrictitle <- paste0(leverage,"x Leveraged Returns/",balance," Balance/",marginutilization,"% Margin Utilization/Compounding")
  } else {
    metrictitle <- paste0(leverage,"x Leveraged Returns/",balance," Balance/",marginutilization,"% Margin Utilization/Not Compounding")
  }
  if (systemcommand == "") {
    print(metrictitle)
  }
  origdigits <- options()$digits
  options(digits=15)
  options(scipen = 999)
  if (systemcommand == "") {
    print(paste("Converting",model,"to Weekly Performance"))
  }
  if (addtotitle == "") {
    addtotitle <- model
  } else {
    addtotitle <- paste(model,addtotitle,':')
  }
  if (is.null(d)) {
    dates <- read.csv("safetygetdates.csv")
    d <- dates[,2:3]
  }
  if (weektoday) {
    wstart <- (wstart - 1)*6 + 1
    wend <- (wend - 1)*6 + 6
  }
  if (systemcommand == "") {
    plotattempt <- try(filteredtrades <- read.csv('modeltrades.csv',header=F))
    if (any(grepl("error",class(plotattempt)))) {
      filteredtrades <- NULL
    }
  } else {
    filteredtrades <- read.csv(pipe(systemcommand,open='r'),header=F)
  }
  if (length(filteredtrades)) {
    xtstrades <- filteredtrades
    xtsprofits <- xtstrades #[seq(2,nrow(xtstrades),2),]

    t1 <- Sys.time()
    weekperf1 <- matrix(nrow=(wend - wstart + 1),ncol=1)
    lastprofit <- 0
    weeklytrades <- NULL
    if (wstart != 1) {
      # print(wstart)
      weeklysum <- 0
      ntrades <- 0
      weeklytrades <- as.numeric(xtsprofits[which(floor(as.numeric(xtsprofits[,4])/1000) >= d[(wstart - 1),1] & floor(as.numeric(xtsprofits[,4])/1000) <= d[(wstart - 1),2]),9])
      allweeklytrades <- xtsprofits[which(floor(as.numeric(xtsprofits[,4])/1000) >= d[(wstart - 1),1] & floor(as.numeric(xtsprofits[,4])/1000) <= d[(wstart - 1),2]),]
      ntrades <- length(weeklytrades)
      if (normalized) {
      lastprofit <- ifelse(length(weeklytrades[ntrades]),tail(cumsum((allweeklytrades[which(allweeklytrades[,2]=="SELL"),5] - allweeklytrades[which(allweeklytrades[,2]=="BUY"),5])/allweeklytrades[which(allweeklytrades[,2]=="BUY"),5] - commissions),1),0)
      } else {
      lastprofit <- ifelse(length(weeklytrades[ntrades]),tail(cumsum(allweeklytrades[which(allweeklytrades[,2]=="SELL"),5] - allweeklytrades[which(allweeklytrades[,2]=="BUY"),5] - commissions),1),0)
      }
      if (verbose) {
        print(paste((wstart - 1),ntrades,weeklysum,ifelse(length(weeklyprofit),weeklyprofit,0)))
        print(lastprofit)
      }
    }
    totaltrades <- 0
    for (week in wstart:wend) {
      weeklysum <- 0
      ntrades <- 0
      weeklytrades <- as.numeric(xtsprofits[which(floor(as.numeric(xtsprofits[,4])/1000) >= d[week,1] & floor(as.numeric(xtsprofits[,4])/1000) <= d[week,2]),9])
allweeklytrades <- xtsprofits[which(floor(as.numeric(xtsprofits[,4])/1000) >= d[week,1] & floor(as.numeric(xtsprofits[,4])/1000) <= d[week,2]),]
#      print(allweeklytrades)
      ntrades <- length(weeklytrades)
      # print(paste0("Number of Trades: ",ntrades))
      totaltrades <- totaltrades + ntrades
      # print(ntrades)
      weeklysum <- weeklytrades[ntrades] - lastprofit
      # print(weeklysum)
      weeklyprofit <- weeklysum - (ntrades * commissions) #0.00008)
      # print(weeklyprofit)
    if (normalized) {
      weekperf1[(week-wstart+1),1] <- ifelse(length(weeklyprofit),tail(cumsum((allweeklytrades[which(allweeklytrades[,2]=="SELL"),5] - allweeklytrades[which(allweeklytrades[,2]=="BUY"),5])/allweeklytrades[which(allweeklytrades[,2]=="BUY"),5] - commissions),1),0) 
    } else {
      weekperf1[(week-wstart+1),1] <- ifelse(length(weeklyprofit),tail(cumsum(allweeklytrades[which(allweeklytrades[,2]=="SELL"),5] - allweeklytrades[which(allweeklytrades[,2]=="BUY"),5] - commissions),1),0)
    }
      # print(weekperf1[(week-wstart+1),1])
      if (length(weeklyprofit)) {
        lastprofit <- weeklytrades[ntrades]
      }
      if (verbose) {
        print(paste(week,ntrades,weeklysum,ifelse(length(weeklyprofit),weeklyprofit,0)))
      }
    }
    # print(paste0('Total Number of Trades: ',totaltrades))
#    if (meanrate != 1) {
#      print(paste('Converting pip profits to percent profit using meanrate of',meanrate))
#      weekperf1 <- weekperf1 / meanrate
#    }
    if (normalized) {
      weekperf1 <- weekperf1*pippercent
    }
    cumweekperf <- cumsum(weekperf1)
    if (plot) {
      plot(wstart:wend,cumweekperf,type='l',col=3,main=paste(addtotitle)) #,'Week',wstart,'to',wend,'Performance'))
      if (legend==T) {legend("topleft",legend = c(paste('Weekly Perf',model,collape=' ')), lty = c(1), col=c(3))}
      abline(0,0)
    }
    if (tplot) {
      # library(timeSeries)
      # library(quantmod)
      if (! "xts" %in% (.packages())) {
        require(xts)
      }
      if (! "PerformanceAnalytics" %in% (.packages())) {
        require(PerformanceAnalytics)
      }
      origperf <- xts(levered*(weekperf1/pippercent)/unlevered*100, order.by=seq(as.POSIXct(d[wstart,1],origin="1970-01-01"),
                                                                      as.POSIXct(d[wend,1],origin="1970-01-01"),length.out=length(wstart:wend)))
      t1 <- xts(levered*(cumweekperf/pippercent)/unlevered*100, order.by=seq(as.POSIXct(d[wstart,1],origin="1970-01-01"),
                                                                  as.POSIXct(d[wend,1],origin="1970-01-01"),length.out=length(wstart:wend)))
      if (metrics==T) {
        # require(PerformanceAnalytics)
        print(Return.annualized(origperf/100, scale = 52, geometric = FALSE))
        print(Return.annualized(origperf/100, scale = 52, geometric = TRUE))
      }
      unleveredamount <- "Cumulative Net Profit [%]"
      if (levered != 100000 || unlevered != 100000) {
        unleveredamount <- paste0("Cumulative Profit [%]: Utilizing ",unlevered," Units Per Trade")
      }
      if (override!="") {
        unleveredamount <- override
      }
      PerformanceAnalytics::chart.TimeSeries(t1,ylab=paste0(unleveredamount),main=paste(addtotitle,system(paste0('date -d @',d[wstart,1],' +%F'),intern=T),'to',system(paste0('date -d @',d[wend,2],' +%F'),intern=T),'Performance'),xlab = "Date (GMT)",cex.lab=.8)
      if (legend==T) {legend("topleft",legend = c(paste('Weekly Perf',model,collape=' ')), lty = c(1), col=c(3))}
      abline(a=0,b=0)
      if (leverage!=1) {
        sim_vec.xts <- xts(weekperf1/pippercent, order.by=seq(as.POSIXct(d[wstart,1],origin="1970-01-01"),
                                                   as.POSIXct(d[wend,1],origin="1970-01-01"),length.out=length(wstart:wend)))
        temp <- sim_vec.xts
        perf_adj <- rep(0,nrow(temp))
        bal <- balance #20000
        mar <- bal * (marginutilization / 100) #2000
        lot <- mar * leverage #100000
        for(i in 1:nrow(temp)) {
          pl <- as.numeric((coredata(temp[i,1])) * lot)
          perf_adj[i] <- as.numeric(pl / bal)
          bal <- bal + pl
          mar <- bal * (marginutilization / 100) # / 5
          if (compounding==T) {
            lot <- mar * leverage #50
          }
          # print(lot)
        }
        
        temp[,1] <- perf_adj
        weekperf1 <- temp*pippercent

        if (metrics==T) {
          metrics <- as.table(rbind(Return.annualized(temp, scale = 52, geometric = T),
                                    AverageDrawdown(temp),
                                    maxDrawdown(temp),
                                    AverageRecovery(temp),
                                    SharpeRatio.annualized(temp, Rf = 0.004/52, scale = 52, geometric = TRUE),
                                    UpsidePotentialRatio(temp, MAR = 0.004/52, method = "full"),
                                    KellyRatio(temp, Rf = 0.004/52, method = "half")))
          print(metrics)
        }
        cumweekperf <- cumsum(weekperf1)
        chart.TimeSeries(cumsum(temp)*100,main=metrictitle,ylab = "Cumulative Net Profit [%]",cex.lab=0.8,cex.main=0.7,xlab="Time")
        }
    }
  } else {
    print("FAILURE: zero lines in trade file: modeltrades.csv")
    if (infnull) {
      weekperf1 <- NULL
      cumweekperf <- NULL
    } else {
      weekperf1 <- rep(-Inf,wend - wstart + 1)
      cumweekperf <- rep(-Inf,wend - wstart + 1)
    }
  }
  if (systemcommand=="") {
    return(list('weekperf'=weekperf1,'cumweekperf'=cumweekperf))
  } else {
    if (!is.null(length(weekperf1))) {
      if (length(weekperf1) != 0) {
        if (tail(cumweekperf,1)>0) {
          print(paste('Result:',-tail(cumweekperf,1)*1/(max(rollmax(cumweekperf,2)-cumweekperf[-1])*sum(weekperf1<=0)/length(weekperf1))**4,-tail(cumweekperf,1),sum(weekperf1<=0),length(weekperf1),max(rollmax(cumweekperf,2)-cumweekperf[-1])))
          return(-tail(cumweekperf,1)*1/(max(rollmax(cumweekperf,2)-cumweekperf[-1])*sum(weekperf1<=0)/length(weekperf1))**4)
        } else {
          print(paste('Result:',-tail(cumweekperf,1)*(max(rollmax(cumweekperf,2)-cumweekperf[-1])*sum(weekperf1<=0)/length(weekperf1))**4,-tail(cumweekperf,1),sum(weekperf1<=0),length(weekperf1),max(rollmax(cumweekperf,2)-cumweekperf[-1])))
          return(-tail(cumweekperf,1)*(max(rollmax(cumweekperf,2)-cumweekperf[-1])*sum(weekperf1<=0)/length(weekperf1))**4)
        }
      } else {
        print("Result: Inf")
        return(Inf)
      }
    } else {
      print("Result: Inf")
      return(Inf)
    }
  }
  options(scipen = 0)
  options(digits=origdigits)
}

