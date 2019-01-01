pb_docker_name <- 'pb'
ISDOCKER <- F

### Uncomment one of the following two settings options that matches your setup:

# ### Option 1: Running R outside of pb_docker_name Docker container:
# currency <- "EURUSD"
# ISNEWTDB <- T
# ISDOCKER <- T
# pbDB <- "ohlc"
# pbTABLE <- "bymin"

# ### Option 2: Running R inside of pb_docker_name Docker container:
# currency <- "EURUSD"
# ISNEWTDB <- T
# pbDB <- "ohlc"
# pbTABLE <- "bymin"
# startingwd <- getwd()
# neededwd <- "/home/ess"

lotsize <- 1 # How many units to trade
offset <- 2 # Real-time Trading Execution Latency
com <- 0.000036 # Broker charge for executing each position
exp <- 30000000 # Expire and close out positions after exp minutes
stopscalar <- "1";
sellbuycondition <- "4"; sellstop <- "0.1050"; selltarget <- "0.1050";
buysellcondition <- "3"; buystop <- "0.1050"; buytarget <- "0.1050";

backtest <- function(normalized=T,runweekly=F,levered=F,balance=20000,marginutilization=10,leverage=50,compounding=F,metrics=F) {
  t1 <- Sys.time()
  if (exists('neededwd')) {
    setwd(neededwd)
  }
  pippercent <- 100
  labelpippercent <- "%"
  if (!normalized) {
    pippercent <- 1
    labelpippercent <- "Pips"
  }
  if (ISDOCKER) {
    dockerprefix1 <- paste0("docker exec ",pb_docker_name,' bash -c "source ~/.bashrc; cd /home/ess;')
    dockerprefix2 <- '"'
  } else {
    dockerprefix1 <- ""
    dockerprefix2 <- ""
  }
  if (sum(grepl('data.table',row.names(installed.packages()),fixed=T)) >= 1) {
    if (! "data.table" %in% (.packages())) {
      library('data.table')
    }
    signals <- fread(paste0(dockerprefix1," aq_udb -exp ",pbDB,':',pbTABLE," -filt 'entrysignal!=0'",dockerprefix2),stringsAsFactors = F,data.table = F)
  } else {
    signalscon <- pipe(paste0(dockerprefix1," aq_udb -exp ",pbDB,':',pbTABLE," -filt 'entrysignal!=0'",dockerprefix2),open='r')
    signals <- read.csv(signalscon,stringsAsFactors = F)
    close(signalscon)
  }
  start <- signals$t[1]
  end <- signals$t[length(signals$t)]
  tdbcon <- pipe(paste0(dockerprefix1," tdb -inf -db ",currency,dockerprefix2),open='r')
  tdbinfo <- read.csv(tdbcon)
  close(tdbcon)
  tdbstart <- tdbinfo[1,1]
  tdbend <- tdbinfo[1,2]
  tdbcount <- tdbinfo[1,3]
  simstart <- max(start,as.integer(tdbstart/1000))
  simend <- min(end,as.integer(tdbend/1000))
  print(paste0("Simulating from ",system(paste0('date -d @',simstart," +'%F'"),intern=T)," (",simstart,') to ',system(paste0('date -d @',simend," +'%F'"),intern=T)," (",simend,")"))
  
  buy.entrytimes <- signals[which(signals$entrysignal == 21),"t"] #Exit Short Positions at Buy Signals
  sell.entrytimes <- signals[which(signals$entrysignal == 12),"t"] #Exit Long Positions at Sell Signals
  buy.expiretimes <- buy.entrytimes*1000+exp*60*1000
  buy.expiretimes[which(buy.expiretimes>tdbend)] <- tdbend
  sell.expiretimes <- sell.entrytimes*1000+exp*60*1000
  sell.expiretimes[which(sell.expiretimes>tdbend)] <- tdbend
  if (ISNEWTDB) {
    buyexpire <- cbind(entryexpire=buy.expiretimes,exitexpire=buy.expiretimes)
    sellexpire <- cbind(entryexpire=sell.expiretimes,exitexpire=sell.expiretimes)
  } else {
    buyexpire <- cbind(entryexpire=buy.expiretimes)
    sellexpire <- cbind(entryexpire=sell.expiretimes)
  }
  buy.entry <- cbind(type=paste0("\"BUY_SELL\""),t=(buy.entrytimes*1000 + offset*1000),buyexpire,price=10000,lo=0,hi=10000,conditioncolumn=paste0("\"trade(",buysellcondition,",",stopscalar,",",buystop,",",buytarget,",0,-1,-1)\""),amount=lotsize)
  sell.entry <- cbind(type=paste0("\"SELL_BUY\""),t=(sell.entrytimes*1000 + offset*1000),sellexpire,price=0,lo=0,hi=10000,conditioncolumn=paste0("\"trade(",sellbuycondition,",",stopscalar,",",sellstop,",",selltarget,",0,-1,-1)\""),amount=lotsize)
  entries <- rbind(buy.entry,sell.entry)[order(c(buy.entrytimes,sell.entrytimes)),]
  write.table(entries,paste0(getwd(),"/financialentrysignals.csv"),row.names=F,quote = F,col.names=F,sep=',')
  if (ISDOCKER) {
    system(paste0('docker cp ',paste0(getwd(),"/financialentrysignals.csv"),' ',pb_docker_name,':/home/ess/financialentrysignals.csv'))
  }
  
  buy.exittimes <- signals[which(signals$entrysignal == 21),"t"] #Exit Short Positions at Buy Signals
  sell.exittimes <- signals[which(signals$entrysignal == 12),"t"] #Exit Long Positions at Sell Signals
  buy.exit <- paste0(as.character(buy.exittimes * 1000 + offset * 1000),",4")
  sell.exit <- paste0(as.character(sell.exittimes * 1000 + offset * 1000),",3")
  buy.exit <- names(sort(sapply(buy.exit,function(x) as.numeric(strsplit(x,",")[[1]][1]))))
  sell.exit <- names(sort(sapply(sell.exit,function(x) as.numeric(strsplit(x,",")[[1]][1]))))
  exits <- sort(c(buy.exit,sell.exit))
  write.table(exits,paste0(getwd(),"/financialexitsignals.csv"),row.names=F,quote = F,col.names=F)
  dir_for_trade_mod <- getwd()
  if (ISDOCKER) {
    system(paste0('docker cp ',paste0(getwd(),"/financialexitsignals.csv"),' ',pb_docker_name,':/home/ess/financialexitsignals.csv'))
    dir_for_trade_mod <- "/home/ess"
  }
  
  sim <- paste0(dockerprefix1,"cat ",dir_for_trade_mod, "/financialentrysignals.csv | tdb -trd,eok,qui - -db ",currency,
                " -seq -mod 'trade(",
                dir_for_trade_mod, "/financialexitsignals.csv",")' ",dockerprefix2)
  
  trades_list <- strsplit(system(sim,intern=TRUE)[-1],",")
  
  if(length(trades_list)>0) {
    trades <- data.frame(matrix(unlist(trades_list),nrow=length(trades_list),byrow=TRUE),stringsAsFactors=FALSE)
    if(sum(grepl("\"SKIPPED WITHOUT ACTION\"",trades[,3]))>0) {
      trades <- trades[-which(trades[,3]=="\"SKIPPED WITHOUT ACTION\""),]
    }
    if(sum(grepl("\"NONE\"",trades[,2]))>0) {
      trades <- trades[-which(trades[,2]=="\"NONE\""),]
    }
    if (ncol(trades)>10) {
      trades[which(trades[,3]=="\"NONE\""),3] <- "\"ORDER SUCCESS\""
      names(trades) <- NULL
      newtrades <- as.data.frame(matrix(0,nrow=nrow(trades)*2,ncol=10))
      newtrades[seq(1,nrow(trades)),] <- trades[,c(1:6,12:15)]
      newtrades[seq((nrow(trades)+1),nrow(newtrades)),] <- trades[,c(1,7:11,12:15)]
      trades <- newtrades[order(newtrades[,4]),]
    }
    weekperfs <- NULL
    leveredweekperfs <- NULL
    if (runweekly && (!ISDOCKER)) {
      if ((sum(grepl('xts',row.names(installed.packages()),fixed=T)) && sum(grepl('PerformanceAnalytics',row.names(installed.packages()),fixed=T))) == T) {
        meanrate <- 1
        if (normalized) {
          meanrate <- mean(as.numeric(trades[,5]))
        }
        print("Running Weekly Performance, will take a few more seconds")
        write.table(trades,'modeltrades.csv',row.names=F,col.names=F,sep=',',quote = F)
        if (!exists('d')) {
          dates <- read.csv(paste0(getwd(),"/funcs.custom/additionalfiles/safetygetdates.csv"))
          d <- dates[,2:3]
        }
        source(paste0(getwd(),'/funcs.custom/additionalfiles/runweekly.R'))
        weekperfs <- runweekly((which(d[,2]>simstart)[1] - 1),(which(d[,1]>simend)[1] - 1),tplot = T,compounding = F,leverage = 1,marginutilization = 100,balance = 100000,metrics = metrics,commissions = com,d = d,meanrate=meanrate,normalized=normalized,pippercent=pippercent)
        if (levered) {
          leveredweekperfs <- runweekly((which(d[,2]>simstart)[1] - 1),(which(d[,1]>simend)[1] - 1),tplot = T,compounding = compounding,leverage = leverage,marginutilization = marginutilization,balance = balance,metrics = metrics,commissions = com,d = d,meanrate=meanrate,normalized=normalized,pippercent=pippercent)
        }
      } else {
        print("runweekly flag requires xts and PerformanceAnalytics Packages, please install them")
      }
    }
  }

  if (normalized) {
    profits <- (as.numeric(trades[which(trades[,2] =="\"SELL\""),5]) - as.numeric(trades[which(trades[,2] =="\"BUY\""),5]))/as.numeric(trades[which(trades[,2] =="\"BUY\""),5]) - com
  } else {
    profits <- as.numeric(trades[which(trades[,2] =="\"SELL\""),5]) - as.numeric(trades[which(trades[,2] =="\"BUY\""),5]) - com
  }
  profits <- profits * pippercent
  
  b_ind <- which(trades[,2]=="\"BUY\"" & trades[,3]=="\"ORDER SUCCESS\"")
  s_ind <- which(trades[,2]=="\"SELL\"" & trades[,3]=="\"ORDER SUCCESS\"")
  if (normalized) {
    buyprofits <- (as.numeric(trades[b_ind+1,5])-as.numeric(trades[b_ind,5]))/as.numeric(trades[b_ind,5])-com
    sellprofits <- (as.numeric(trades[s_ind,5])-as.numeric(trades[s_ind+1,5]))/as.numeric(trades[s_ind+1,5])-com
  } else {
    buyprofits <- as.numeric(trades[b_ind+1,5])-as.numeric(trades[b_ind,5])-com
    sellprofits <- as.numeric(trades[s_ind,5])-as.numeric(trades[s_ind+1,5])-com
  }
  buyprofits <- buyprofits * pippercent
  sellprofits <- sellprofits * pippercent
  buyentrytime <-  (as.numeric(trades[which(trades[,2]=="\"BUY\"" & trades[,3]=="\"ORDER SUCCESS\""),4])-offset*1000)/1000
  sellentrytime <-  (as.numeric(trades[which(trades[,2]=="\"SELL\"" & trades[,3]=="\"ORDER SUCCESS\""),4])-offset*1000)/1000
  buyexittime <-  (as.numeric(trades[which(trades[,2]=="\"SELL\"" & trades[,3]!="\"ORDER SUCCESS\""),4]))/1000
  sellexittime <- (as.numeric(trades[which(trades[,2]=="\"BUY\"" & trades[,3]!="\"ORDER SUCCESS\""),4]))/1000
  bt <- (buyexittime-buyentrytime)/60
  st <- (sellexittime-sellentrytime)/60
  par(mfrow=c(1,2))
  plot(buyprofits,bt,type="p",main="Long Position Net Profits",xlab=ifelse(normalized,"Net Profit [%]","Net Profit [Pips]"),ylab="Minutes")
  abline(v=0,col=2)
  plot(sellprofits,st,type="p",main="Short Position Net Profits",xlab=ifelse(normalized,"Net Profit [%]","Net Profit [Pips]"),ylab="Minutes")
  abline(v=0,col=2)
  
  cumprofits <- cumsum(profits)
  profit <- tail(cumprofits,1)
  par(mfrow=c(1,1))
  plot(cumprofits,type="l",main="Cumulative Net Profit",xlab=paste0(system(paste0('date -d @',simstart," +'%F'"),intern=T),' to ',system(paste0('date -d @',simend," +'%F'"),intern=T)),ylab=ifelse(normalized,"Net Profit [%]","Net Profit [Pips]"))
  
  t2 <- Sys.time()
  print(paste0("Simulated ",tdbcount," Data Points in ",t2 - t1," Seconds"))
  print(paste0("Total Net Profit: ",profit,' ',labelpippercent))
    
  leveredprofits <- NULL
  if (levered) {
    leveredprofits <- rep(0,length(profits))
    bal <- balance
    mar <- bal / (100 / marginutilization)
    lot <- mar * leverage
    for(i in 1:length(profits)) {
      pl <- (profits[i]/pippercent) * lot
      leveredprofits[i] <- pl / bal
      bal <- bal + pl
      mar <- bal * (marginutilization / 100)
      if (compounding==T) {
        lot <- mar * leverage
      }
      # print(lot)
    }
    leveredprofits <- leveredprofits*pippercent
    
    print(paste0("Total Leveraged Net Profit: ",tail(cumsum(leveredprofits),1),' ',labelpippercent))    
    plot(cumsum(leveredprofits),main=paste0(leverage,"x Leveraged Returns/",marginutilization,"% Margin Utilization/Not Compounding"),ylab = ifelse(normalized,"Cumulative Net Profit [%]","Cumulative Net Profit [Pips]"),xlab=paste0('Trades from ',system(paste0('date -d @',simstart," +'%F'"),intern=T),' to ',system(paste0('date -d @',simend," +'%F'"),intern=T)),type='l',cex.lab=0.8,cex.main=0.8)

  }
  
  if (exists('startingwd')) {
    setwd(startingwd)
  }

  return(list("totalprofit"=profit,"normalized"=normalized,"profits"=profits,"cumprofits"=cumprofits,"buyprofits"=buyprofits,"sellprofits"=sellprofits,"leveredprofits"=leveredprofits,"weekperfs"=weekperfs,"leveredweekperfs"=leveredweekperfs,"trades"=trades))
}

modelresults <- backtest()

str(modelresults)

