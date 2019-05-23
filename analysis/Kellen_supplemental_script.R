####################################################
#             Supplemental Script of               #
# Elementary Signal Detection and Threshold Theory #
#        David Kellen and Karl Christoph Klauer    #
#              (code by David Kellen)              #
####################################################


rm(list=ls())
require(MPTinR)
require(pbivnorm)
require(mnormt)
require(mdsdt)

#################################
# W. K. Estes' unpublished data #
#################################


data_CV <- c(0.57, 0.80, 0.82, 0.76, 0.80, 0.60)
data_CV <- c(rbind(data_CV,1-data_CV))*117


caseV <- "

pnorm((Ei-Ch)/sqrt(2))
1-pnorm((Ei-Ch)/sqrt(2))

pnorm((Ei-Ha)/sqrt(2))
1-pnorm((Ei-Ha)/sqrt(2))

pnorm((Ei-Fa)/sqrt(2))
1-pnorm((Ei-Fa)/sqrt(2))

pnorm((Ch-Ha)/sqrt(2))
1-pnorm((Ch-Ha)/sqrt(2))

pnorm((Ch-Fa)/sqrt(2))
1-pnorm((Ch-Fa)/sqrt(2))

pnorm((Ha-Fa)/sqrt(2))
1-pnorm((Ha-Fa)/sqrt(2))
"

fit_r0 <- fit.model(data_CV,textConnection(caseV),lower.bound = rep(-Inf,3), upper.bound = rep(Inf,3), rest = list("Fa = 0"), show.messages = FALSE) # fit case V
fit_r0$goodness.of.fit # fit with MLE
fit_r0$parameters # MLE parameters

###########################################
# Example Thurstone Ranking  (Equation 5) #
###########################################


rank <- function(mu1,mu2,mu3,ss1=1,ss2=1,ss3=1){
  f2 <- function(y,mu2,ss2,mu3,ss3) vapply(y,function(yy,mu2,mu3,ss2,ss3){dnorm(yy,mu2,ss2)*pnorm(yy,mu3,ss3)},0,mu2=mu2,ss2=ss2,mu3=mu3,ss3=ss3)
  f1 <- function(x,mu1,ss1,mu2,ss2,mu3,ss3) vapply(x,function(xx,mu1,ss1,mu2,mu3,ss2,ss3){dnorm(xx,mu1,ss1)*integrate(f2,-Inf,xx,mu2=mu2,ss2=ss2,mu3=mu3,ss3=ss3)$value},0,mu1=mu1,ss1=ss1,mu2=mu2,ss2=ss2,mu3=mu3,ss3=ss3)
  f0 <- function(mu1,ss1,mu2,ss2,mu3,ss3) integrate(f1,-Inf,Inf,mu1=mu1,ss1=ss1,mu2=mu2,ss2=ss2,mu3=mu3,ss3=ss3)$value

  return(f0(mu1,ss1,mu2,ss2,mu3,ss3))
}

rank(1.8, 1.2, 0.4) # a > b > c
rank(0.4, 1.8, 1.2) # c > a > b

#########################
# basic EVSDT measures  #
#########################

EVSDT <- function(FA,H,Ns=1,Nn=1,correction=FALSE){
  # can use correction described in Footnote 9
  # If correction = TRUE, FA and H have to be frequencies (and you need to give the total number of signal and noise observations, Nn and Ns).
  # If corrrection = FALSE, you can simply give H nd FA as proportions (ignore Nn and Ns).

      tH  <- (H  + 0.5*correction)/(Ns + 1*correction)
      tFA <- (FA + 0.5*correction)/(Nn + 1*correction)

      d <- qnorm(tH) - qnorm(tFA)
      kappa <-  -qnorm(tFA)
      C <- -0.5*(qnorm(tH) + qnorm(tFA))
      log_beta <- C*d
      return(data.frame(d,kappa,C, log_beta))
}


# pair example
round(EVSDT(0.788,0.964),2)
round(EVSDT(0.211,0.579),2)

mean(c(1-0.788,0.964))# proportion correct
mean(c(1-0.211,0.579))# proportion correct

round(EVSDT(14,28, 30, 30),2) # example using frequencies, without correction
round(EVSDT(14,28, 30, 30, correction = TRUE),2) # example using frequencies, with correction

# triplet example
round(EVSDT(0.30,0.50),2) # {FA,H}
round(EVSDT(0.30,0.80),2) # {FA,H*}
round(EVSDT(0.50,0.80),2) # {H,H*}

EVSDT(0.30,0.80)[1] - EVSDT(0.30,0.50)[1]  - EVSDT(0.50,0.80)[1] # d' difference between pairings from the triplet



####################################################
# Z-based and LR-based test of EVSDT's d and kappa #
####################################################


# function to compute the Z-test

z_tests <- function(data1,data2, Nn1,Ns1,Nn2,Ns2, correction=FALSE){

      tFA1 <- (data1[1]  + 0.5*correction)/(Nn1 + 1*correction)
      tH1  <- (data1[2]  + 0.5*correction)/(Ns1 + 1*correction)
      tFA2 <- (data2[1]  + 0.5*correction)/(Nn2 + 1*correction)
      tH2  <- (data2[2]  + 0.5*correction)/(Ns2 + 1*correction)

      d1 <- qnorm(tH1) - qnorm(tFA1)
      d2 <- qnorm(tH2) - qnorm(tFA2)
      k1 <- - qnorm(tFA1)
      k2 <- - qnorm(tFA2)

      kappa1 <-  -qnorm(tFA1)
      kappa2 <-  -qnorm(tFA2)

      sk1 <- tFA1*(1-tFA1)/(Nn1*dnorm(qnorm(tFA1))**2)
      sk2 <- tFA2*(1-tFA2)/(Nn2*dnorm(qnorm(tFA2))**2)
      sd1 <- tFA1*(1-tFA1)/(Nn1*dnorm(qnorm(tFA1))**2) + tH1*(1-tH1)/(Ns1*dnorm(qnorm(tH1))**2)
      sd2 <- tFA2*(1-tFA2)/(Nn2*dnorm(qnorm(tFA2))**2) + tH2*(1-tH2)/(Ns2*dnorm(qnorm(tH2))**2)

      Zd <- (d1 - d2)/sqrt(sd1 + sd2)
      Zk <- (k1 - k2)/sqrt(sk1 + sk2)

      p_value_d <- 2*pnorm(-abs(Zd)) # two-tailed test for d
      p_value_k <- 2*pnorm(-abs(Zk)) # two-tailed test for k

      return(data.frame(Zd,p_value_d,Zk,p_value_k))
}

# model for EVSDT measures
m_evsdt <- "
1-pnorm(-kappa1)
pnorm(-kappa1)

1-pnorm(mu1-kappa1)
pnorm(mu1-kappa1)

1-pnorm(-kappa2)
pnorm(-kappa2)

1-pnorm(mu2-kappa2)
pnorm(mu2-kappa2)
"

# some random data
data1 <- c(20,52)
data2 <- c(30,75)
Nn1 <- Nn2 <- 100
Ns1 <- Ns2 <- 100

# ML fits of the EVSDT model
fit_r0 <- fit.model(c(c(rbind(data1, c(Nn1,Ns1) - data1)),c(rbind(data2, c(Nn2,Ns2) - data2))),textConnection(m_evsdt),lower.bound = rep(-Inf,4), upper.bound = rep(Inf,4), show.messages = FALSE) # saturated model
fit_r1 <- fit.model(c(c(rbind(data1, c(Nn1,Ns1) - data1)),c(rbind(data2, c(Nn2,Ns2) - data2))),textConnection(m_evsdt), rest = list("mu1 = mu2"),lower.bound = rep(-Inf,3), upper.bound = rep(Inf,3), show.messages = FALSE) # test d
fit_r2 <- fit.model(c(c(rbind(data1, c(Nn1,Ns1) - data1)),c(rbind(data2, c(Nn2,Ns2) - data2))),textConnection(m_evsdt), rest = list("kappa1 = kappa2"),lower.bound = rep(-Inf,3), upper.bound = rep(Inf,3), show.messages = FALSE) # test kappa


fit_r0$parameters # measures obtained with MLE
fit_r1$goodness.of.fit  # LR test for d
fit_r2$goodness.of.fit  # LR test for kappa

z_tests(data1,data2, Nn1,Ns1,Nn2,Ns2, correction=FALSE) # Z-test for d and kappa



#####################################################
# EVSDT fit of binary-response ROC data (Figure 6)  #
#####################################################


SDT <- "
    pnorm((mu-cr1)/ss)
1 - pnorm((mu-cr1)/ss)

    pnorm((mu-cr2)/ss)
1 - pnorm((mu-cr2)/ss)

    pnorm((mu-cr3)/ss)
1 - pnorm((mu-cr3)/ss)

    pnorm((mu-cr4)/ss)
1 - pnorm((mu-cr4)/ss)

    pnorm((mu-cr5)/ss)
1 - pnorm((mu-cr5)/ss)

    pnorm((  -cr1))
1 - pnorm((  -cr1))

    pnorm((  -cr2))
1 - pnorm((  -cr2))

    pnorm((  -cr3))
1 - pnorm((  -cr3))

    pnorm((  -cr4))
1 - pnorm((  -cr4))

    pnorm((  -cr5))
1 - pnorm((  -cr5))
"




dmat <- c(20.1, 39.9, 91.8, 88.2, 214.5, 85.5, 329.7, 90.3, 499.5, 40.5,
48.6, 491.4, 86.1, 333.9, 120, 180, 88.2, 91.8, 41.4, 18.6)

# fit EVSDT #
fit_EVSDT <- fit.model(dmat,textConnection(SDT),lower.bound=c(rep(-Inf,5),0),upper.bound=rep(Inf,6), n.optim=100, restrictions=list("ss=1"), show.messages = FALSE)

fit_EVSDT$goodness.of.fit
fit_EVSDT$parameters




##########################################################
# SDT fit of binary-response ROC data  (Figures 8 and 9) #
##########################################################


data <- c(86, 114, 86, 114, 128, 72, 128, 72, 112, 88, 142, 58, 152,
48, 154, 46, 168, 32, 172, 28, 166, 34, 174, 26, 186, 14, 0,
200, 8, 192, 12, 188, 24, 176, 10, 190, 34, 166, 28, 172, 36,
164, 68, 132, 68, 132, 70, 130, 98, 102, 148, 52)



SDT <- "

    pnorm((mu-cr1)/ss)
1 - pnorm((mu-cr1)/ss)

    pnorm((mu-cr2)/ss)
1 - pnorm((mu-cr2)/ss)

    pnorm((mu-cr3)/ss)
1 - pnorm((mu-cr3)/ss)

    pnorm((mu-cr4)/ss)
1 - pnorm((mu-cr4)/ss)

    pnorm((mu-cr5)/ss)
1 - pnorm((mu-cr5)/ss)

    pnorm((mu-cr6)/ss)
1 - pnorm((mu-cr6)/ss)

    pnorm((mu-cr7)/ss)
1 - pnorm((mu-cr7)/ss)

    pnorm((mu-cr8)/ss)
1 - pnorm((mu-cr8)/ss)

    pnorm((mu-cr9)/ss)
1 - pnorm((mu-cr9)/ss)

    pnorm((mu-cr10)/ss)
1 - pnorm((mu-cr10)/ss)

    pnorm((mu-cr11)/ss)
1 - pnorm((mu-cr11)/ss)

    pnorm((mu-cr12)/ss)
1 - pnorm((mu-cr12)/ss)

    pnorm((mu-cr13)/ss)
1 - pnorm((mu-cr13)/ss)

    pnorm((  -cr1))
1 - pnorm((  -cr1))

    pnorm((  -cr2))
1 - pnorm((  -cr2))

    pnorm((  -cr3))
1 - pnorm((  -cr3))

    pnorm((  -cr4))
1 - pnorm((  -cr4))

    pnorm((  -cr5))
1 - pnorm((  -cr5))

    pnorm((  -cr6))
1 - pnorm((  -cr6))

    pnorm((  -cr7))
1 - pnorm((  -cr7))

    pnorm((  -cr8))
1 - pnorm((  -cr8))

    pnorm((  -cr9))
1 - pnorm((  -cr9))

    pnorm((  -cr10))
1 - pnorm((  -cr10))

    pnorm((  -cr11))
1 - pnorm((  -cr11))

    pnorm((  -cr12))
1 - pnorm((  -cr12))

    pnorm((  -cr13))
1 - pnorm((  -cr13))
"


MSDT <- "
Z*(    pnorm((mu-cr1)) ) + (1-Z)*(    pnorm((  -cr1)) )
Z*(1 - pnorm((mu-cr1)) ) + (1-Z)*(1 - pnorm((  -cr1)) )

Z*(    pnorm((mu-cr2)) ) + (1-Z)*(    pnorm((  -cr2)) )
Z*(1 - pnorm((mu-cr2)) ) + (1-Z)*(1 - pnorm((  -cr2)) )

Z*(    pnorm((mu-cr3)) ) + (1-Z)*(    pnorm((  -cr3)) )
Z*(1 - pnorm((mu-cr3)) ) + (1-Z)*(1 - pnorm((  -cr3)) )

Z*(    pnorm((mu-cr4)) ) + (1-Z)*(    pnorm((  -cr4)) )
Z*(1 - pnorm((mu-cr4)) ) + (1-Z)*(1 - pnorm((  -cr4)) )

Z*(    pnorm((mu-cr5)) ) + (1-Z)*(    pnorm((  -cr5)) )
Z*(1 - pnorm((mu-cr5)) ) + (1-Z)*(1 - pnorm((  -cr5)) )

Z*(    pnorm((mu-cr6)) ) + (1-Z)*(    pnorm((  -cr6)) )
Z*(1 - pnorm((mu-cr6)) ) + (1-Z)*(1 - pnorm((  -cr6)) )

Z*(    pnorm((mu-cr7)) ) + (1-Z)*(    pnorm((  -cr7)) )
Z*(1 - pnorm((mu-cr7)) ) + (1-Z)*(1 - pnorm((  -cr7)) )

Z*(    pnorm((mu-cr8)) ) + (1-Z)*(    pnorm((  -cr8)) )
Z*(1 - pnorm((mu-cr8)) ) + (1-Z)*(1 - pnorm((  -cr8)) )

Z*(    pnorm((mu-cr9)) ) + (1-Z)*(    pnorm((  -cr9)) )
Z*(1 - pnorm((mu-cr9)) ) + (1-Z)*(1 - pnorm((  -cr9)) )

Z*(    pnorm((mu-cr10))) + (1-Z)*(    pnorm((  -cr10)))
Z*(1 - pnorm((mu-cr10))) + (1-Z)*(1 - pnorm((  -cr10)))

Z*(    pnorm((mu-cr11))) + (1-Z)*(    pnorm((  -cr11)))
Z*(1 - pnorm((mu-cr11))) + (1-Z)*(1 - pnorm((  -cr11)))

Z*(    pnorm((mu-cr12))) + (1-Z)*(    pnorm((  -cr12)))
Z*(1 - pnorm((mu-cr12))) + (1-Z)*(1 - pnorm((  -cr12)))

Z*(    pnorm((mu-cr13))) + (1-Z)*(    pnorm((  -cr13)))
Z*(1 - pnorm((mu-cr13))) + (1-Z)*(1 - pnorm((  -cr13)))

(    pnorm((  -cr1)) )
(1 - pnorm((  -cr1)) )

(    pnorm((  -cr2)) )
(1 - pnorm((  -cr2)) )

(    pnorm((  -cr3)) )
(1 - pnorm((  -cr3)) )

(    pnorm((  -cr4)) )
(1 - pnorm((  -cr4)) )

(    pnorm((  -cr5)) )
(1 - pnorm((  -cr5)) )

(    pnorm((  -cr6)) )
(1 - pnorm((  -cr6)) )

(    pnorm((  -cr7)) )
(1 - pnorm((  -cr7)) )

(    pnorm((  -cr8)) )
(1 - pnorm((  -cr8)) )

(    pnorm((  -cr9)) )
(1 - pnorm((  -cr9)) )

(    pnorm((  -cr10)))
(1 - pnorm((  -cr10)))

(    pnorm((  -cr11)))
(1 - pnorm((  -cr11)))

(    pnorm((  -cr12)))
(1 - pnorm((  -cr12)))

(    pnorm((  -cr13)))
(1 - pnorm((  -cr13)))
"




XSDT <- "
    exp(-exp(cr1-mu))
1 - exp(-exp(cr1-mu))

    exp(-exp(cr2-mu))
1 - exp(-exp(cr2-mu))

    exp(-exp(cr3-mu))
1 - exp(-exp(cr3-mu))

    exp(-exp(cr4-mu))
1 - exp(-exp(cr4-mu))

    exp(-exp(cr5-mu))
1 - exp(-exp(cr5-mu))

    exp(-exp(cr6-mu))
1 - exp(-exp(cr6-mu))

    exp(-exp(cr7-mu))
1 - exp(-exp(cr7-mu))

    exp(-exp(cr8-mu))
1 - exp(-exp(cr8-mu))

    exp(-exp(cr9-mu))
1 - exp(-exp(cr9-mu))

    exp(-exp(cr10-mu))
1 - exp(-exp(cr10-mu))

    exp(-exp(cr11-mu))
1 - exp(-exp(cr11-mu))

    exp(-exp(cr12-mu))
1 - exp(-exp(cr12-mu))

    exp(-exp(cr13-mu))
1 - exp(-exp(cr13-mu))

    exp(-exp(cr1))
1 - exp(-exp(cr1))

    exp(-exp(cr2))
1 - exp(-exp(cr2))

    exp(-exp(cr3))
1 - exp(-exp(cr3))

    exp(-exp(cr4))
1 - exp(-exp(cr4))

    exp(-exp(cr5))
1 - exp(-exp(cr5))

    exp(-exp(cr6))
1 - exp(-exp(cr6))

    exp(-exp(cr7))
1 - exp(-exp(cr7))

    exp(-exp(cr8))
1 - exp(-exp(cr8))

    exp(-exp(cr9))
1 - exp(-exp(cr9))

    exp(-exp(cr10))
1 - exp(-exp(cr10))

    exp(-exp(cr11))
1 - exp(-exp(cr11))

    exp(-exp(cr12))
1 - exp(-exp(cr12))

    exp(-exp(cr13))
1 - exp(-exp(cr13))
"


# fit models #
fit_EVSDT <- fit.model(data,textConnection(SDT),lower.bound=c(rep(-Inf,13),0),upper.bound=rep(Inf,14), n.optim=100, rest=list("ss=1"), show.messages = FALSE)
fit_UVSDT <- fit.model(data,textConnection(SDT),lower.bound=c(rep(-Inf,13),0,0.1),upper.bound=rep(Inf,15), n.optim=100, show.messages = FALSE)

fit_MSDT <- fit.model(data,textConnection(MSDT),lower.bound=c(rep(-Inf,13),0,0),upper.bound=c(rep(Inf,14),1), n.optim=100, show.messages = FALSE)
fit_XSDT <- fit.model(data,textConnection(XSDT),lower.bound=c(rep(-Inf,13),0),upper.bound=c(rep(Inf,14)), n.optim=100, show.messages = FALSE)

# EVSDT
fit_EVSDT$goodness.of.fit # goodness of fit
fit_EVSDT$parameters # parameters

# UVSDT
fit_UVSDT$goodness.of.fit # goodness of fit
fit_UVSDT$parameters # parameter

# MSDT
fit_MSDT$goodness.of.fit # goodness of fit
fit_MSDT$parameters # parameter

# XSDT
fit_XSDT$goodness.of.fit # goodness of fit
fit_XSDT$parameters # parameter





########################################################
# UVSDT fit of confidence-rating ROC data  (Figure 11) #
########################################################


# Ratclif et al. (1994, MS condition)
data_cr <- c(172,355,345,283,308,432,788,1585,1160,656,555,299)

UVSDT <-"
pnorm((cr1 - mu)/ss)
pnorm((cr1+cr2 - mu)/ss) - pnorm((cr1 - mu)/ss)
pnorm((cr1+cr2+cr3 - mu)/ss) - pnorm((cr1+cr2 - mu)/ss)
pnorm((cr1+cr2+cr3+cr4 - mu)/ss) - pnorm((cr1+cr2+cr3 - mu)/ss)
pnorm((cr1+cr2+cr3+cr4+cr5 - mu)/ss) - pnorm((cr1+cr2+cr3+cr4 - mu)/ss)
1 - pnorm((cr1+cr2+cr3+cr4+cr5 - mu)/ss)

pnorm((cr1))
pnorm((cr1+cr2)) - pnorm((cr1))
pnorm((cr1+cr2+cr3)) - pnorm((cr1+cr2))
pnorm((cr1+cr2+cr3+cr4)) - pnorm((cr1+cr2+cr3))
pnorm((cr1+cr2+cr3+cr4+cr5)) - pnorm((cr1+cr2+cr3+cr4))
1 - pnorm((cr1+cr2+cr3+cr4+cr5))
"


fit_UVSDT <- fit.model(data_cr,textConnection(UVSDT),lower.bound=c(-Inf,rep(0,4),0,0.1),upper.bound=rep(Inf,7), n.optim=5, show.messages = FALSE)



fit_UVSDT$goodness.of.fit # goodness of fit
fit_UVSDT$parameters # parameters


######################################################################
# UVSDT fit of confidence-rating ROC mirror-effect data  (Figure 12) #
######################################################################




data <- c(
102, 197, 116, 139, 177, 438,
433, 518, 285, 184, 165, 163,
125, 167, 112, 99, 195, 644,
543, 488, 237, 102, 107, 99
)




UVSDT_me <-"
pnorm((cr1 - muoH)/ssoH)
pnorm((cr1+cr2 - muoH)/ssoH) - pnorm((cr1 - muoH)/ssoH)
pnorm((cr1+cr2+cr3 - muoH)/ssoH) - pnorm((cr1+cr2 - muoH)/ssoH)
pnorm((cr1+cr2+cr3+cr4 - muoH)/ssoH) - pnorm((cr1+cr2+cr3 - muoH)/ssoH)
pnorm((cr1+cr2+cr3+cr4+cr5 - muoH)/ssoH) - pnorm((cr1+cr2+cr3+cr4 - muoH)/ssoH)
1 - pnorm((cr1+cr2+cr3+cr4+cr5 - muoH)/ssoH)

pnorm((cr1 - munH)/ssnH)
pnorm((cr1+cr2 - munH)/ssnH) - pnorm((cr1 - munH)/ssnH)
pnorm((cr1+cr2+cr3 - munH)/ssnH) - pnorm((cr1+cr2 - munH)/ssnH)
pnorm((cr1+cr2+cr3+cr4 - munH)/ssnH) - pnorm((cr1+cr2+cr3 - munH)/ssnH)
pnorm((cr1+cr2+cr3+cr4+cr5 - munH)/ssnH) - pnorm((cr1+cr2+cr3+cr4 - munH)/ssnH)
1 - pnorm((cr1+cr2+cr3+cr4+cr5 - munH)/ssnH)

pnorm((cr1 - muoL)/ssoL)
pnorm((cr1+cr2 - muoL)/ssoL) - pnorm((cr1 - muoL)/ssoL)
pnorm((cr1+cr2+cr3 - muoL)/ssoL) - pnorm((cr1+cr2 - muoL)/ssoL)
pnorm((cr1+cr2+cr3+cr4 - muoL)/ssoL) - pnorm((cr1+cr2+cr3 - muoL)/ssoL)
pnorm((cr1+cr2+cr3+cr4+cr5 - muoL)/ssoL) - pnorm((cr1+cr2+cr3+cr4 - muoL)/ssoL)
1 - pnorm((cr1+cr2+cr3+cr4+cr5 - muoL)/ssoL)

pnorm((cr1))
pnorm((cr1+cr2)) - pnorm((cr1))
pnorm((cr1+cr2+cr3)) - pnorm((cr1+cr2))
pnorm((cr1+cr2+cr3+cr4)) - pnorm((cr1+cr2+cr3))
pnorm((cr1+cr2+cr3+cr4+cr5)) - pnorm((cr1+cr2+cr3+cr4))
1 - pnorm((cr1+cr2+cr3+cr4+cr5))
"

# full model
fit_UVSDT_me <- fit.model(data,textConnection(UVSDT_me),lower.bound=c(-Inf,rep(0,4),0,0,0, 0.1,0.1,0.1),upper.bound=rep(Inf,11), n.optim=5, show.messages = FALSE)

fit_UVSDT_me$goodness.of.fit
fit_UVSDT_me$parameters


# restricted model
fit_UVSDT_me_r <- fit.model(data,textConnection(UVSDT_me),lower.bound=c(-Inf,rep(0,4),0, 0.1),upper.bound=rep(Inf,7), restrictions=list("muoH = muoL","ssoH = ssoL", "munH =0", "ssnH=1"), n.optim=5, show.messages = FALSE)

fit_UVSDT_me_r$goodness.of.fit
fit_UVSDT_me_r$parameters




#####################################################
# UVSDT fit of 2AFC mirror-effect data  (Figure 13) #
#####################################################


data_2afc_me <- c(.74, .78, .80, .83, .65, .60)
data_2afc_me <- c(rbind(data_2afc_me,1-data_2afc_me))*100





UVSDT_2afc_me <- function(Q, data, param.names, n.params, tmp.env, lower.bound, upper.bound){


  f2c <- function(mu1=0,ss1=1,mu2=0,ss2=1){
        ff <- function(x, mu1,ss1,mu2,ss2){dnorm(x,mu1,ss1)*pnorm(x,mu2,ss2)}
        integrate(ff,-Inf,Inf,mu1=mu1,ss1=ss1,mu2=mu2,ss2=ss2)$value
}


  mHO <- Q[1]
  mLO <- Q[2]
  mHN <- 0
  mLN <- Q[3]

  sHO <- Q[4]
  sLO <- Q[5]
  sHN <- 1
  sLN <- Q[6]



e <- c()

e[1]  <-    f2c(mHO,sHO,mHN,sHN)
e[2]  <-  1-f2c(mHO,sHO,mHN,sHN)

e[3]  <-    f2c(mLO,sLO,mHN,sHN)
e[4]  <-  1-f2c(mLO,sLO,mHN,sHN)

e[5]  <-    f2c(mHO,sHO,mLN,sLN)
e[6]  <-  1-f2c(mHO,sHO,mLN,sLN)

e[7]  <-    f2c(mLO,sLO,mLN,sLN)
e[8]  <-  1-f2c(mLO,sLO,mLN,sLN)

e[9]  <-    f2c(mHN,sHN,mLN,sLN)
e[10] <-  1-f2c(mHN,sHN,mLN,sLN)

e[11] <-    f2c(mLO,sLO,mHO,sHO)
e[12] <-  1-f2c(mLO,sLO,mHO,sHO)


    LL <- -sum(data[data!=0]*log(e[data!=0]))
    return(LL)
}



fit_2afc_me <- fit.mptinr(data_2afc_me, UVSDT_2afc_me, c("mHO","mLO","mLN","sHO","sLO","sLN"), c(2,2,2,2,2,2), lower.bound = c(rep(-Inf,3),rep(0.01,3)), upper.bound = Inf, n.optim = 20,show.messages = FALSE)

fit_2afc_me$goodness.of.fit
fit_2afc_me$parameters



#######################################
# UVSDT fit of kAFC data  (Figure 14) #
#######################################

SDT_kafc <- function(Q, data, param.names, n.params, tmp.env, lower.bound, upper.bound){

    e<-vector("numeric",4)

    mu <- Q[1]
    ss <- Q[2]

    rank <- function(i,k,mu=1,ss=1){
            f1 <- function(x,i,k,mu,ss) choose(k -1, i-1)*dnorm(x,mu,ss)*pnorm(x)**(k-i)*(1-pnorm(x))**(i-1)
            tmp <- vector("numeric",length=length(i))
            for(ii in 1:length(i)) tmp[ii] <- integrate(f1,lower = -Inf, upper=Inf, i=i[ii],k=k,mu=mu,ss=ss) $value
            return(tmp)
    }


    e[1:2]  <- rank(1:2,2,mu=mu,ss=ss)
    e[3:4]  <- c(rank(1,3,mu=mu,ss=ss), 1- rank(1,3,mu=mu,ss=ss))
    e[5:6]  <- c(rank(1,4,mu=mu,ss=ss), 1- rank(1,4,mu=mu,ss=ss) )
    e[7:8]  <- c(rank(1,6,mu=mu,ss=ss), 1- rank(1,6,mu=mu,ss=ss))
    e[9:10] <- c(rank(1,8,mu=mu,ss=ss), 1- rank(1,8,mu=mu,ss=ss) )


    LL <- -sum(data[data!=0]*log(e[data!=0]))
    return(LL)
}


data_kafc <- structure(c(259.44, 255.63, 253.23, 40.56, 44.37, 46.77, 394.15,
382.2, 374.05, 105.85, 117.8, 125.95, 428.4, 445.5, 453.54, 171.6,
154.5, 146.46, 595.89, 571.05, 582.75, 304.11, 328.95, 317.25,
737.4, 680.52, 711.72, 462.6, 519.48, 488.28), .Dim = c(3L, 10L
))


fit_kafc <- fit.mptinr(data_kafc, SDT_kafc, c("mu", "sigma"), c(2,2,2,2,2), lower.bound = c(0,0.1), upper.bound = Inf, n.optim = 5,show.messages = FALSE)

fit_kafc$goodness.of.fit$individual
fit_kafc$parameters$individual


#############################################
# EVSDT fit of 3AFC data with order effects #
#############################################

EVSDT_3AFC <- function(Q, data, param.names, n.params, tmp.env, lower.bound, upper.bound){

mu  <- Q[1]
kk1 <- Q[2]
kk2 <- Q[3]
kk3 <- 0

rr <- function(mu,kk1=0,kk2=0,kk3=0){
  f <- function(x,mu,kk1,kk2,kk3) dnorm(x-kk1,mu)*pnorm(x-kk2)*pnorm(x-kk3)
  integrate(f,-Inf,Inf,mu=mu,kk1=kk1,kk2=kk2,kk3=kk3)$value
}

e <- c()

e[1] <-  rr(mu,kk1,kk2,kk3)
e[2] <-  1-rr(mu,kk1,kk2,kk3)

e[3] <-  rr(mu,kk2,kk1,kk3)
e[4] <-  1-rr(mu,kk2,kk1,kk3)

e[5] <-  rr(mu,kk3,kk1,kk2)
e[6] <-  1-rr(mu,kk3,kk1,kk2)

LL <- -sum(data[data!=0]*log(e[data!=0]))
    return(LL)
}



  data <- c(40,20,49,10,49,11)
  fit_EVSDT_3AFC <- fit.mptinr(data, EVSDT_3AFC, c("mu", "kk1","kk2"), c(2,2,2), lower.bound = c(-Inf,-Inf,-Inf), upper.bound =Inf,n.optim=5)

fit_EVSDT_3AFC$goodness.of.fit
fit_EVSDT_3AFC$parameters




##########################################
# comparison of ROC moments  (Figure 15) #
##########################################


data_KKS <- structure(c(39, 80, 75, 35, 61, 54, 73, 52, 44, 63, 40, 48, 80,
49, 43, 80, 68, 53, 81, 60, 60, 65, 49, 58, 69, 75, 71, 47, 44,
85, 23, 9, 11, 21, 12, 21, 14, 20, 19, 15, 29, 13, 14, 15, 22,
11, 12, 16, 13, 20, 20, 9, 26, 19, 13, 9, 14, 15, 24, 9, 19,
7, 9, 26, 16, 14, 6, 17, 21, 14, 20, 18, 5, 19, 17, 5, 11, 21,
4, 9, 15, 17, 7, 17, 11, 11, 9, 19, 20, 3, 19, 4, 5, 18, 11,
11, 7, 11, 16, 8, 11, 21, 1, 17, 18, 4, 9, 10, 2, 11, 5, 9, 18,
6, 7, 5, 6, 19, 12, 3, 8, 4, 0, 8, 4, 1, 7, 4, 33, 1, 0, 0, 7,
11, 1, 2, 1, 5, 1, 2, 15, 40, 5, 8, 16, 0, 3, 4, 7, 0, 12, 7,
3, 23, 6, 1, 4, 15, 12, 8, 6, 7, 3, 10, 10, 10, 8, 28, 7, 12,
2, 3, 11, 30, 1, 6, 16, 19, 19, 4, 16, 10, 10, 13, 13, 6, 6,
19, 13, 30, 26, 32, 6, 13, 19, 12, 15, 13, 10, 25, 6, 4, 17,
2, 17, 11, 6, 13, 16, 3, 24, 14, 17, 13, 16, 16, 15, 29, 14,
22, 14, 17, 6, 14, 15, 16, 14, 10, 13, 12, 7, 4, 17, 2, 9, 18,
7, 13, 29, 4, 22, 11, 15, 18, 12, 24, 5, 12, 6, 10, 22, 21, 6,
19, 19, 19, 10, 15, 13, 19, 4, 1, 18, 8, 1, 30, 13, 23, 19, 11,
18, 54, 55, 25, 49, 52, 63, 21, 22, 29, 32, 23, 72, 33, 36, 41,
52, 29, 56, 30, 66, 48, 32, 50, 56, 35, 55, 28, 10, 78, 18, 16,
1, 18, 17, 1, 50, 13, 51, 8, 0, 0, 46, 27, 2, 9, 18, 16, 19,
11, 61, 83, 29, 37, 41, 5, 12, 10, 16, 32, 18, 30, 21, 23, 22,
2, 17, 29, 20, 29, 23, 21, 16, 20, 31, 47, 35, 46, 29, 42, 6,
0, 18, 43, 4, 45, 48, 38, 16, 41, 19, 26, 34, 12, 26, 19, 19,
31, 11, 40, 35, 57, 14, 14, 27, 26, 30, 15, 15, 31, 7, 4, 16,
4, 27, 24, 13, 17, 26, 12, 16, 19, 31, 21, 17, 43, 8, 23, 7,
18, 16, 17, 14, 17, 15, 14, 13, 15, 24, 13, 8, 3, 14, 3, 15,
17, 15, 20, 23, 6, 24, 8, 11, 12, 9, 27, 2, 4, 2, 4, 22, 5, 4,
12, 24, 2, 4, 8, 7, 3, 4, 2, 16, 7, 2, 5, 12, 13, 18, 4, 5, 1,
2, 14, 9, 8, 4, 0, 9, 1, 4, 0, 6, 10, 1, 2, 0, 0, 6, 0, 14, 8,
7, 6, 11, 4, 0, 2, 1, 5), .Dim = c(30L, 16L))

# compute ranks and conditional ranks of old items
rnkp <- data_KKS[,1:4]/100
rtgp <- data_KKS[,-c(1:4)]/100
rtgp <- cbind(0,t(apply(rtgp[,12:7],1,cumsum)),0,t(apply(rtgp[,6:1],1,cumsum)))


# compute moments based on ROC data
mrt <- matrix(NA,30,3)
for(ii in 1:30){
  frt <- approxfun(rtgp[ii,1:7],rtgp[ii,8:14])
  frt2 <- function(x)frt(x)**2
  frt3 <- function(x)frt(x)**3
  mrt[ii,] <- c(integrate(frt,0,1)$value, integrate(frt2,0,1)$value, integrate(frt3,0,1)$value)

}

# compute proportion correct across k based on ranks
gg <- function(rnpi,j){ iii=0:(4-j); sum(choose(4-1-iii,j-1)*rnpi[iii+1])/choose(4-1,j-1)}

mrk <- matrix(NA,ncol=3,nrow=30)
for(kk in 1:30) mrk[kk,] <- c(gg(rnkp[kk,],2),gg(rnkp[kk,],3),gg(rnkp[kk,],4))

cor.test(mrt[,1],mrk[,1])
cor.test(mrt[,2],mrk[,2])
cor.test(mrt[,3],mrk[,3])

t.test(mrt[,1],mrk[,1],paired=TRUE)
t.test(mrt[,2],mrk[,2],paired=TRUE)
t.test(mrt[,3],mrk[,3],paired=TRUE)




#######################
# GRT fit (Figure 17) #
#######################

# Data from Thomas (2001) #

# Rows and columns (see Table 2)

data_GRT <- structure(c(83, 38, 15, 6, 112, 154, 27, 36, 47, 28, 117, 75,
11, 33, 94, 136), .Dim = c(4L, 4L))


# macro-analyses #

###########
# sampling independence
###########

sain <-"
p*q
p*(1-q)
(1-p)*q
(1-p)*(1-q)
"
# goodness of fit for each quadrant
round(fit.mpt(data_GRT,textConnection(sain),show.messages = FALSE)$goodness.of.fit$individual,3)


###########
# marginal response invariance
###########


dta1 <- c(data_GRT[1,1]+data_GRT[1,2], data_GRT[1,3]+data_GRT[1,4], data_GRT[2,1]+data_GRT[2,2], data_GRT[2,3]+data_GRT[2,4])
dta2 <- c(data_GRT[3,3]+data_GRT[3,4], data_GRT[3,1]+data_GRT[3,2], data_GRT[4,3]+data_GRT[4,4], data_GRT[4,1]+data_GRT[4,2])
dtb1 <- c(data_GRT[1,1]+data_GRT[1,3], data_GRT[1,2]+data_GRT[1,4], data_GRT[3,1]+data_GRT[3,3], data_GRT[3,2]+data_GRT[3,4])
dtb2 <- c(data_GRT[2,2]+data_GRT[2,4], data_GRT[2,1]+data_GRT[2,3], data_GRT[4,2]+data_GRT[4,4], data_GRT[4,1]+data_GRT[4,3])


mri <-"
p
1-p

p
1-p
"
fit.mpt(dta1,textConnection(mri),show.messages = FALSE)$goodness.of.fit
fit.mpt(dta2,textConnection(mri),show.messages = FALSE)$goodness.of.fit
fit.mpt(dtb1,textConnection(mri),show.messages = FALSE)$goodness.of.fit
fit.mpt(dtb2,textConnection(mri),show.messages = FALSE)$goodness.of.fit


# fit GRT #

summary(fit.grt(data_GRT))
summary(fit.grt(data_GRT, PI="same_rho"))
summary(fit.grt(data_GRT, PI="all"))

plot(fit.grt(data_GRT, PI="same_rho"))

###################################
# Bivariate UVSDT fit (Figure 18) #
###################################


#### Yonelinas (1999, Experiment 2) ####

## data
data <- c(489, 119, 62, 40, 56, 84, 24, 105, 51, 40, 45, 9, 8, 33, 82,
                 54, 26, 1, 5, 20, 101, 86, 8, 3, 8, 26, 113, 78, 4, 1, 3, 16,
                 83, 30, 5, 2, 79, 64, 75, 40, 119, 433, 12, 77, 43, 48, 71, 10,
                 2, 35, 84, 68, 27, 3, 4, 34, 119, 82, 7, 0, 4, 29, 130, 75, 2,
                 2, 6, 16, 71, 43, 3, 3, 22, 20, 14, 9, 24, 12, 15, 54, 37, 35,
                 48, 11, 15, 38, 124, 57, 20, 2, 3, 49, 166, 118, 8, 1, 14, 37,
                 296, 181, 15, 4, 9, 46, 246, 150, 13, 7)



## bivariate UVSDT model proposed by deCarlo (2003), but with piecewise criteria ##

D2SDT <- function(Q, data){



MA <- Q[c(1,2)]
MB <- Q[c(3,4)]
MN <- c(0,0)
CVA <- matrix(c(Q[5]**2, Q[5]*Q[6]*Q[7],  Q[5]*Q[6]*Q[7],  Q[6]**2),2,2,byrow=TRUE)
CVB <- matrix(c(Q[8]**2, Q[8]*Q[9]*Q[10], Q[8]*Q[9]*Q[10], Q[9]**2),2,2,byrow=TRUE)
CVN <- diag(2)

cx <- matrix(NA,6,5); cx <- cbind(rep(-Inf,6),cx,rep(Inf,6))

cx[1,2:6] <- cumsum(Q[11:15])
cx[2,2:6] <- cumsum(Q[16:20])
cx[3,2:6] <- cumsum(Q[21:25])
cx[4,2:6] <- cumsum(Q[26:30])
cx[5,2:6] <- cumsum(Q[31:35])
cx[6,2:6] <- cumsum(Q[36:40])

cy <- c(-Inf,cumsum(Q[41:45]),Inf)

e <- c()

e[ 1] <- sadmvn(c(cx[6,1],cy[6]),c(cx[6,2],cy[7]), mean=MA,varcov=CVA)[1]
e[ 2] <- sadmvn(c(cx[6,2],cy[6]),c(cx[6,3],cy[7]), mean=MA,varcov=CVA)[1]
e[ 3] <- sadmvn(c(cx[6,3],cy[6]),c(cx[6,4],cy[7]), mean=MA,varcov=CVA)[1]
e[ 4] <- sadmvn(c(cx[6,4],cy[6]),c(cx[6,5],cy[7]), mean=MA,varcov=CVA)[1]
e[ 5] <- sadmvn(c(cx[6,5],cy[6]),c(cx[6,6],cy[7]), mean=MA,varcov=CVA)[1]
e[ 6] <- sadmvn(c(cx[6,6],cy[6]),c(cx[6,7],cy[7]), mean=MA,varcov=CVA)[1]
e[ 7] <- sadmvn(c(cx[5,1],cy[5]),c(cx[5,2],cy[6]), mean=MA,varcov=CVA)[1]
e[ 8] <- sadmvn(c(cx[5,2],cy[5]),c(cx[5,3],cy[6]), mean=MA,varcov=CVA)[1]
e[ 9] <- sadmvn(c(cx[5,3],cy[5]),c(cx[5,4],cy[6]), mean=MA,varcov=CVA)[1]
e[10] <- sadmvn(c(cx[5,4],cy[5]),c(cx[5,5],cy[6]), mean=MA,varcov=CVA)[1]
e[11] <- sadmvn(c(cx[5,5],cy[5]),c(cx[5,6],cy[6]), mean=MA,varcov=CVA)[1]
e[12] <- sadmvn(c(cx[5,6],cy[5]),c(cx[5,7],cy[6]), mean=MA,varcov=CVA)[1]
e[13] <- sadmvn(c(cx[4,1],cy[4]),c(cx[4,2],cy[5]), mean=MA,varcov=CVA)[1]
e[14] <- sadmvn(c(cx[4,2],cy[4]),c(cx[4,3],cy[5]), mean=MA,varcov=CVA)[1]
e[15] <- sadmvn(c(cx[4,3],cy[4]),c(cx[4,4],cy[5]), mean=MA,varcov=CVA)[1]
e[16] <- sadmvn(c(cx[4,4],cy[4]),c(cx[4,5],cy[5]), mean=MA,varcov=CVA)[1]
e[17] <- sadmvn(c(cx[4,5],cy[4]),c(cx[4,6],cy[5]), mean=MA,varcov=CVA)[1]
e[18] <- sadmvn(c(cx[4,6],cy[4]),c(cx[4,7],cy[5]), mean=MA,varcov=CVA)[1]
e[19] <- sadmvn(c(cx[3,1],cy[3]),c(cx[3,2],cy[4]), mean=MA,varcov=CVA)[1]
e[20] <- sadmvn(c(cx[3,2],cy[3]),c(cx[3,3],cy[4]), mean=MA,varcov=CVA)[1]
e[21] <- sadmvn(c(cx[3,3],cy[3]),c(cx[3,4],cy[4]), mean=MA,varcov=CVA)[1]
e[22] <- sadmvn(c(cx[3,4],cy[3]),c(cx[3,5],cy[4]), mean=MA,varcov=CVA)[1]
e[23] <- sadmvn(c(cx[3,5],cy[3]),c(cx[3,6],cy[4]), mean=MA,varcov=CVA)[1]
e[24] <- sadmvn(c(cx[3,6],cy[3]),c(cx[3,7],cy[4]), mean=MA,varcov=CVA)[1]
e[25] <- sadmvn(c(cx[2,1],cy[2]),c(cx[2,2],cy[3]), mean=MA,varcov=CVA)[1]
e[26] <- sadmvn(c(cx[2,2],cy[2]),c(cx[2,3],cy[3]), mean=MA,varcov=CVA)[1]
e[27] <- sadmvn(c(cx[2,3],cy[2]),c(cx[2,4],cy[3]), mean=MA,varcov=CVA)[1]
e[28] <- sadmvn(c(cx[2,4],cy[2]),c(cx[2,5],cy[3]), mean=MA,varcov=CVA)[1]
e[29] <- sadmvn(c(cx[2,5],cy[2]),c(cx[2,6],cy[3]), mean=MA,varcov=CVA)[1]
e[30] <- sadmvn(c(cx[2,6],cy[2]),c(cx[2,7],cy[3]), mean=MA,varcov=CVA)[1]
e[31] <- sadmvn(c(cx[1,1],cy[1]),c(cx[1,2],cy[2]), mean=MA,varcov=CVA)[1]
e[32] <- sadmvn(c(cx[1,2],cy[1]),c(cx[1,3],cy[2]), mean=MA,varcov=CVA)[1]
e[33] <- sadmvn(c(cx[1,3],cy[1]),c(cx[1,4],cy[2]), mean=MA,varcov=CVA)[1]
e[34] <- sadmvn(c(cx[1,4],cy[1]),c(cx[1,5],cy[2]), mean=MA,varcov=CVA)[1]
e[35] <- sadmvn(c(cx[1,5],cy[1]),c(cx[1,6],cy[2]), mean=MA,varcov=CVA)[1]
e[36] <- sadmvn(c(cx[1,6],cy[1]),c(cx[1,7],cy[2]), mean=MA,varcov=CVA)[1]

e[ 1+36] <- sadmvn(c(cx[6,1],cy[6]),c(cx[6,2],cy[7]), mean=MB,varcov=CVB)[1]
e[ 2+36] <- sadmvn(c(cx[6,2],cy[6]),c(cx[6,3],cy[7]), mean=MB,varcov=CVB)[1]
e[ 3+36] <- sadmvn(c(cx[6,3],cy[6]),c(cx[6,4],cy[7]), mean=MB,varcov=CVB)[1]
e[ 4+36] <- sadmvn(c(cx[6,4],cy[6]),c(cx[6,5],cy[7]), mean=MB,varcov=CVB)[1]
e[ 5+36] <- sadmvn(c(cx[6,5],cy[6]),c(cx[6,6],cy[7]), mean=MB,varcov=CVB)[1]
e[ 6+36] <- sadmvn(c(cx[6,6],cy[6]),c(cx[6,7],cy[7]), mean=MB,varcov=CVB)[1]
e[ 7+36] <- sadmvn(c(cx[5,1],cy[5]),c(cx[5,2],cy[6]), mean=MB,varcov=CVB)[1]
e[ 8+36] <- sadmvn(c(cx[5,2],cy[5]),c(cx[5,3],cy[6]), mean=MB,varcov=CVB)[1]
e[ 9+36] <- sadmvn(c(cx[5,3],cy[5]),c(cx[5,4],cy[6]), mean=MB,varcov=CVB)[1]
e[10+36] <- sadmvn(c(cx[5,4],cy[5]),c(cx[5,5],cy[6]), mean=MB,varcov=CVB)[1]
e[11+36] <- sadmvn(c(cx[5,5],cy[5]),c(cx[5,6],cy[6]), mean=MB,varcov=CVB)[1]
e[12+36] <- sadmvn(c(cx[5,6],cy[5]),c(cx[5,7],cy[6]), mean=MB,varcov=CVB)[1]
e[13+36] <- sadmvn(c(cx[4,1],cy[4]),c(cx[4,2],cy[5]), mean=MB,varcov=CVB)[1]
e[14+36] <- sadmvn(c(cx[4,2],cy[4]),c(cx[4,3],cy[5]), mean=MB,varcov=CVB)[1]
e[15+36] <- sadmvn(c(cx[4,3],cy[4]),c(cx[4,4],cy[5]), mean=MB,varcov=CVB)[1]
e[16+36] <- sadmvn(c(cx[4,4],cy[4]),c(cx[4,5],cy[5]), mean=MB,varcov=CVB)[1]
e[17+36] <- sadmvn(c(cx[4,5],cy[4]),c(cx[4,6],cy[5]), mean=MB,varcov=CVB)[1]
e[18+36] <- sadmvn(c(cx[4,6],cy[4]),c(cx[4,7],cy[5]), mean=MB,varcov=CVB)[1]
e[19+36] <- sadmvn(c(cx[3,1],cy[3]),c(cx[3,2],cy[4]), mean=MB,varcov=CVB)[1]
e[20+36] <- sadmvn(c(cx[3,2],cy[3]),c(cx[3,3],cy[4]), mean=MB,varcov=CVB)[1]
e[21+36] <- sadmvn(c(cx[3,3],cy[3]),c(cx[3,4],cy[4]), mean=MB,varcov=CVB)[1]
e[22+36] <- sadmvn(c(cx[3,4],cy[3]),c(cx[3,5],cy[4]), mean=MB,varcov=CVB)[1]
e[23+36] <- sadmvn(c(cx[3,5],cy[3]),c(cx[3,6],cy[4]), mean=MB,varcov=CVB)[1]
e[24+36] <- sadmvn(c(cx[3,6],cy[3]),c(cx[3,7],cy[4]), mean=MB,varcov=CVB)[1]
e[25+36] <- sadmvn(c(cx[2,1],cy[2]),c(cx[2,2],cy[3]), mean=MB,varcov=CVB)[1]
e[26+36] <- sadmvn(c(cx[2,2],cy[2]),c(cx[2,3],cy[3]), mean=MB,varcov=CVB)[1]
e[27+36] <- sadmvn(c(cx[2,3],cy[2]),c(cx[2,4],cy[3]), mean=MB,varcov=CVB)[1]
e[28+36] <- sadmvn(c(cx[2,4],cy[2]),c(cx[2,5],cy[3]), mean=MB,varcov=CVB)[1]
e[29+36] <- sadmvn(c(cx[2,5],cy[2]),c(cx[2,6],cy[3]), mean=MB,varcov=CVB)[1]
e[30+36] <- sadmvn(c(cx[2,6],cy[2]),c(cx[2,7],cy[3]), mean=MB,varcov=CVB)[1]
e[31+36] <- sadmvn(c(cx[1,1],cy[1]),c(cx[1,2],cy[2]), mean=MB,varcov=CVB)[1]
e[32+36] <- sadmvn(c(cx[1,2],cy[1]),c(cx[1,3],cy[2]), mean=MB,varcov=CVB)[1]
e[33+36] <- sadmvn(c(cx[1,3],cy[1]),c(cx[1,4],cy[2]), mean=MB,varcov=CVB)[1]
e[34+36] <- sadmvn(c(cx[1,4],cy[1]),c(cx[1,5],cy[2]), mean=MB,varcov=CVB)[1]
e[35+36] <- sadmvn(c(cx[1,5],cy[1]),c(cx[1,6],cy[2]), mean=MB,varcov=CVB)[1]
e[36+36] <- sadmvn(c(cx[1,6],cy[1]),c(cx[1,7],cy[2]), mean=MB,varcov=CVB)[1]

e[ 1+72] <- sadmvn(c(cx[6,1],cy[6]),c(cx[6,2],cy[7]), mean=MN,varcov=CVN)[1]
e[ 2+72] <- sadmvn(c(cx[6,2],cy[6]),c(cx[6,3],cy[7]), mean=MN,varcov=CVN)[1]
e[ 3+72] <- sadmvn(c(cx[6,3],cy[6]),c(cx[6,4],cy[7]), mean=MN,varcov=CVN)[1]
e[ 4+72] <- sadmvn(c(cx[6,4],cy[6]),c(cx[6,5],cy[7]), mean=MN,varcov=CVN)[1]
e[ 5+72] <- sadmvn(c(cx[6,5],cy[6]),c(cx[6,6],cy[7]), mean=MN,varcov=CVN)[1]
e[ 6+72] <- sadmvn(c(cx[6,6],cy[6]),c(cx[6,7],cy[7]), mean=MN,varcov=CVN)[1]
e[ 7+72] <- sadmvn(c(cx[5,1],cy[5]),c(cx[5,2],cy[6]), mean=MN,varcov=CVN)[1]
e[ 8+72] <- sadmvn(c(cx[5,2],cy[5]),c(cx[5,3],cy[6]), mean=MN,varcov=CVN)[1]
e[ 9+72] <- sadmvn(c(cx[5,3],cy[5]),c(cx[5,4],cy[6]), mean=MN,varcov=CVN)[1]
e[10+72] <- sadmvn(c(cx[5,4],cy[5]),c(cx[5,5],cy[6]), mean=MN,varcov=CVN)[1]
e[11+72] <- sadmvn(c(cx[5,5],cy[5]),c(cx[5,6],cy[6]), mean=MN,varcov=CVN)[1]
e[12+72] <- sadmvn(c(cx[5,6],cy[5]),c(cx[5,7],cy[6]), mean=MN,varcov=CVN)[1]
e[13+72] <- sadmvn(c(cx[4,1],cy[4]),c(cx[4,2],cy[5]), mean=MN,varcov=CVN)[1]
e[14+72] <- sadmvn(c(cx[4,2],cy[4]),c(cx[4,3],cy[5]), mean=MN,varcov=CVN)[1]
e[15+72] <- sadmvn(c(cx[4,3],cy[4]),c(cx[4,4],cy[5]), mean=MN,varcov=CVN)[1]
e[16+72] <- sadmvn(c(cx[4,4],cy[4]),c(cx[4,5],cy[5]), mean=MN,varcov=CVN)[1]
e[17+72] <- sadmvn(c(cx[4,5],cy[4]),c(cx[4,6],cy[5]), mean=MN,varcov=CVN)[1]
e[18+72] <- sadmvn(c(cx[4,6],cy[4]),c(cx[4,7],cy[5]), mean=MN,varcov=CVN)[1]
e[19+72] <- sadmvn(c(cx[3,1],cy[3]),c(cx[3,2],cy[4]), mean=MN,varcov=CVN)[1]
e[20+72] <- sadmvn(c(cx[3,2],cy[3]),c(cx[3,3],cy[4]), mean=MN,varcov=CVN)[1]
e[21+72] <- sadmvn(c(cx[3,3],cy[3]),c(cx[3,4],cy[4]), mean=MN,varcov=CVN)[1]
e[22+72] <- sadmvn(c(cx[3,4],cy[3]),c(cx[3,5],cy[4]), mean=MN,varcov=CVN)[1]
e[23+72] <- sadmvn(c(cx[3,5],cy[3]),c(cx[3,6],cy[4]), mean=MN,varcov=CVN)[1]
e[24+72] <- sadmvn(c(cx[3,6],cy[3]),c(cx[3,7],cy[4]), mean=MN,varcov=CVN)[1]
e[25+72] <- sadmvn(c(cx[2,1],cy[2]),c(cx[2,2],cy[3]), mean=MN,varcov=CVN)[1]
e[26+72] <- sadmvn(c(cx[2,2],cy[2]),c(cx[2,3],cy[3]), mean=MN,varcov=CVN)[1]
e[27+72] <- sadmvn(c(cx[2,3],cy[2]),c(cx[2,4],cy[3]), mean=MN,varcov=CVN)[1]
e[28+72] <- sadmvn(c(cx[2,4],cy[2]),c(cx[2,5],cy[3]), mean=MN,varcov=CVN)[1]
e[29+72] <- sadmvn(c(cx[2,5],cy[2]),c(cx[2,6],cy[3]), mean=MN,varcov=CVN)[1]
e[30+72] <- sadmvn(c(cx[2,6],cy[2]),c(cx[2,7],cy[3]), mean=MN,varcov=CVN)[1]
e[31+72] <- sadmvn(c(cx[1,1],cy[1]),c(cx[1,2],cy[2]), mean=MN,varcov=CVN)[1]
e[32+72] <- sadmvn(c(cx[1,2],cy[1]),c(cx[1,3],cy[2]), mean=MN,varcov=CVN)[1]
e[33+72] <- sadmvn(c(cx[1,3],cy[1]),c(cx[1,4],cy[2]), mean=MN,varcov=CVN)[1]
e[34+72] <- sadmvn(c(cx[1,4],cy[1]),c(cx[1,5],cy[2]), mean=MN,varcov=CVN)[1]
e[35+72] <- sadmvn(c(cx[1,5],cy[1]),c(cx[1,6],cy[2]), mean=MN,varcov=CVN)[1]
e[36+72] <- sadmvn(c(cx[1,6],cy[1]),c(cx[1,7],cy[2]), mean=MN,varcov=CVN)[1]


e <- e*c(rep(sum(data[1:36]),36),rep(sum(data[37:72]),36),rep(sum(data[73:108]),36))

Gsq <- 2*sum(data[data!=0]*(log(data[data!=0])-log(e[data!=0])))
print(Gsq)
return(Gsq)
}


# start values and fit constraints
start <- c(runif(1,-1.5,0),runif(1,0,1.5),runif(1,0,1.5),runif(1,0,1.5), runif(2,0.5,1.5),runif(1,-1,1), runif(2,0.5,1.5),runif(1,-1,1),c(replicate(7,c(runif(1,-2,0),runif(4,0.4)))))
lower= c(rep(-Inf,4),rep(-Inf,2),-1,rep(-Inf,2),-1,rep(c(-20,rep(0.001,4)),7))
upper= c(rep(Inf,4),rep(Inf,2),1,rep(Inf,2),1,rep(c(20,rep(10,4)),7))

# can sometimes fail
fit <- optim(start,D2SDT,lower=lower,upper=upper,data=data) # G^2 is printed



