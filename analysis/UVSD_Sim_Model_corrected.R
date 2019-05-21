# ====================================================================
# Functions for SARMAC Workshop 2018
# An Introduction to MLE using SDT for Eyewitness Identification Data
# 4 criteria, Unequal Variance SDT model
# Max Familiarity Decision Rule
#
# By Carolyn Semmler, John Dunn & Matthew Kaesler - University of Adelaide
# January 2018
# ====================================================================



#Simulated Data


#     c1  c2  c3  c4  c5  c6
#CID  111 22  13  5   1   0   Last cell is theoretically empty as there is no "no choose" response for Correct IDs
#TD   116 29  28  18  5   4   Last cell is no choose on TP lineups 
#FA   39  40  50  42  22  8   Last cell is correct rejections


#Simulated Data
#obs.data <- matrix(data = c(111,22,13,5,1,0,
#                            116,29,28,18,5,4,
#                           39,40,50,42,22,8), 
#                   nrow = 3,
#                   ncol = 6,
#                   byrow = TRUE)

#pars <- c(1.8, 1.4, 1, 0.6, 0.2, 2, 1) c1, c2, c3, c4, c5, d, s used to simulate data above 

obs.data <- matrix(data = c(34,28,11,3,2,NA, # Short Exposure Frequency counts 
                            35,32,15,5,3,10,
                            7,13,14,7,4,50),
                   
                   nrow = 3,
                   ncol = 6,
                   byrow = TRUE)

n <- 6 #lineup size



#Likelihood functions generate predicted data.
#Given a particular set of parameters that define the likelihood surface, they give the most likely data

#Predicted proportion of Correct IDs according to MAX model
QT <- function(c,d,s,n){
  m <- function(x) dnorm(x,mean = d, sd = s)*pnorm(x)^(n-1)
  p <- vector(mode = "integer", length = length(c))
  for (i in 1:length(c)){
    a <- integrate(m,c[i],15) 
    p[i] <- a$value
  }
  return(p)
}

#predicted proportion of total detections on TP trials MAX model
TP <- function(c,d,s,n){
  p <- vector(mode = "integer", length = length(c))
  for (i in 1:length(c)){
    p[i] <- pnorm(((c[i])-d)/s)*pnorm(c[i])^(n-1)
  }
  p <- 1 - p
  return(p)
}

#predicted proportion of total detections on TA trials MAX model
TA <- function(c,n){
  p = vector(mode = "integer", length = length(c))
  for (i in 1:length(c)){
    p[i] = pnorm(c[i])^n
  }
  p = 1 - p
  return(p)
}

genpred <- function(pars, obs.data, n){
  
  c <- pars[1:(length(pars)-2)]
  d <- pars[length(pars)-1]
  s <- tail(pars,1)
  
  total.TP <- sum(obs.data[2,])
  total.TA <- sum(obs.data[3,]) 
  
  CID <- QT(c(c, -15),d,s,n)
  CID <- c(CID[1],diff(CID))
  
  TDTP <- c(TP(c,d,s,n),1)
  TDTP <- c(TDTP[1],diff(TDTP))
  
  TDTA <- c(TA(c,n),1)
  TDTA <- c(TDTA[1],diff(TDTA))
  
  CID <- CID*total.TP
  TDTP <- TDTP*total.TP
  TDTA <- TDTA*total.TA
  
  pred.data <- rbind(CID,TDTP,TDTA)
  rownames(pred.data) <- c()
  
  return(pred.data)
}

#Chi-squared 

chisq <- function(pars,obs.data,n){
  
  pred.data <- genpred(pars,obs.data,n)
  lastcell <- ncol(obs.data)  
  nc <- ncol(obs.data)-1
  f <- vector(mode = "integer", length = nrow(obs.data)*ncol(obs.data)) #for storing and summing chi-sq fit value
  
  for (i in 1:nc){
    
    a <- pred.data[1,i] #Correct ID 
    b <- obs.data[1,i]
    f[1] <- f[1] + (b-a)^2/a
    
    a <- pred.data[2,i]-pred.data[1,i] #Foil ID on TP lineup 
    b <- obs.data[2,i]-obs.data[1,i] 
    f[2] = f[2] + (b-a)^2/a
    
    a <- pred.data[3,i] #False Alarm 
    b <- obs.data[3,i]
    f[3] <- f[3] + (b-a)^2/a
  }
  
  a <- pred.data[2,lastcell] #Rejection TP
  b <- obs.data[2,lastcell]
  f[4] <- (b-a)^2/a
  
  a <- pred.data[3,lastcell] #Rejection TA
  b <- obs.data[3,lastcell]
  f[5] <- (b-a)^2/a
  
  f <- sum(f)
  
  return(f)  
}

#optimisation


x0 = c(5,4,3,2,1,1,1) #c1, c2, c3, c4, c5, d, s

A <- cbind(c(1,0,0,0),c(-1,1,0,0),c(0,-1,1,0),c(0,0,-1,1),c(0,0,0,-1),c(0,0,0,0),c(0,0,0,0)) #added extra column for s parameter
b <- c(0,0,0,0)

#Optimize using the constraints so that the criteria do not cross-over in the solution. 

out <- constrOptim(theta = x0, f = chisq, grad = NULL, ui = A, ci = b, mu = 1e-04, method = "Nelder-Mead",  
                   outer.iterations = 100, obs.data = obs.data, n = n)

#get fit statistic and parameters from model fit

chisq.modelfit <- out$value
c.modelfit <- out$par[1:(length(out$par)-2)]
d.modelfit <- out$par[length(out$par)-1]
s.modelfit <- tail(out$par,1)

pred.data <- genpred(out$par, obs.data, n)
