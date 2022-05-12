library(MicroMoB)
library(jsonlite) 
library(jsonvalidate)
library(rstudioapi)

# make parameters for new schema
p <- 20
tmax <- 1095

surv_a <- 0.9

adult_stochastic <- TRUE
adult_f <- 0.3
adult_q <- 0.9
adult_eip <- rep(10, tmax)
adult_p <- t(replicate(n = p, expr = {(sin((1:tmax)/365*2*pi) + 2)/2 * surv_a}))
adult_psi <- diag(p)
adult_nu <- 25
adult_M <- rpois(n = p, lambda = 100)
adult_Y <- rep(0, times = p)
adult_Z <- rep(0, times = p)

molt <- 0.1
surv <- 0.9

aqua_stochastic <- TRUE
aqua_molt <- matrix(data = molt, nrow = p, ncol = tmax)
aqua_surv <- matrix(data = surv, nrow = p, ncol = tmax)

lambda <- adult_M*(1-surv_a)
eggs <- adult_nu * adult_f * adult_M

aqua_L <- lambda * ((1/molt) - 1) + eggs
aqua_K <- - (lambda * aqua_L) / (lambda - aqua_L*molt*surv)
aqua_K <- t(sapply(X = aqua_K, FUN = function(x) {rep(x, tmax)}))

input <- list(
  p = p,
  tmax = tmax,
  aqua_stochastic = aqua_stochastic,
  aqua_molt = aqua_molt,
  aqua_surv = aqua_surv,
  aqua_K = aqua_K,
  aqua_L = aqua_L,
  adult_stochastic = adult_stochastic,
  adult_f = adult_f,
  adult_q = adult_q,
  adult_eip = adult_eip,
  adult_p = adult_p,
  adult_psi = adult_psi,
  adult_nu = adult_nu,
  adult_M = adult_M,
  adult_Y = adult_Y,
  adult_Z = adult_Z
)

jsonlite::write_json(x = input, path = "input/input.json",digits=17,pretty=TRUE)

jsonvalidate::json_validate(json = "input/input.json", schema = "schema/input-MicroMoB.json")

# old ----------------------------------------------------------------------
ARGS <- commandArgs(trailingOnly=TRUE)
print(ARGS)
# IO
if(length(ARGS)>1){
  config_in <- ARGS[1]
  adult_in <- ARGS[2]
  aqua_in <- ARGS[3]
  model_out <- ARGS[4]
  config_in_schema <- ARGS[5]
  adult_in_schema <- ARGS[6]
  aqua_in_schame <- ARGS[7]
  model_out_schema <- ARGS[8]
} else {
  config_in <- "test/config.json"
  adult_in <- "test/adult_par.json"
  aqua_in <- "test/aqua_par.json"
  model_out <- "output/data.json"
  config_in_schema <- "schema/config.json"
  adult_in_schema <- "schema/adult_par.json"
  aqua_in_schame <- "schema/aqua_par.json"
  model_out_schema <- "schema/output.json"
}

config_check <- jsonvalidate::json_validate(config_in, config_in_schema)
adult_check <- jsonvalidate::json_validate(adult_in, adult_in_schema)
aqua_check <- jsonvalidate::json_validate(aqua_in, aqua_in_schame)
if(!config_check | !adult_check | !aqua_check){
  quit(save="no",status=1)
}

main_config <- MicroMoB::api_config_global(path = config_in)

# read in aquatic config file
if (main_config$aqua_model == "BH") {
  aqua_pars <- MicroMoB::get_config_aqua_BH(path = aqua_in)
} else if (main_config$aqua_model == "trace") {
  aqua_pars <- MicroMoB::get_config_aqua_trace(path = aqua_in)
} else {
  stop("invalid aquatic model specified")
}

# read in adult config file
if (main_config$adult_model == "RM") {
  adult_pars <- MicroMoB::get_config_mosquito_RM(path = adult_in)
} else {
  stop("invalid adult model specified")
}

# create model object
mod <- MicroMoB::make_MicroMoB(tmax = main_config$tmax, p = main_config$p)

# setup adult component
if (main_config$adult_model == "RM") {
  setup_mosquito_RM(
    model = mod,
    stochastic = adult_pars$stochastic,
    f = adult_pars$f,
    q = adult_pars$q,
    eip = adult_pars$eip,
    p = adult_pars$p,
    psi = adult_pars$psi,
    nu = adult_pars$nu,
    M = adult_pars$M,
    Y = adult_pars$Y,
    Z = adult_pars$Z
  )
} else {
  stop("unknown adult mosquito model specified")
}

# setup aquatic component
if (main_config$aqua_model == "trace") {
  setup_aqua_trace(
    model = mod,
    lambda = aqua_pars$lambda,
    stochastic = aqua_pars$stochastic
  )
} else if (main_config$aqua_model == "BH") {
  setup_aqua_BH(
    model = mod,
    stochastic = aqua_pars$stochastic,
    molt = aqua_pars$molt,
    surv = aqua_pars$surv,
    K = aqua_pars$K,
    L = aqua_pars$L
  )
} else {
  stop("unknown aquatic mosquito model specified")
}

# output is stored in an array (patches X timesteps X life stages)
output <- array(NaN, dim = c(main_config$p, main_config$tmax + 1, 3))
output[, 1, ] <- c(mod$aqua$L, mod$aqua$A, mod$mosquito$M)

# run simulation
while (mod$global$tnow <= main_config$tmax) {
  step_aqua(model = mod)
  step_mosquitoes(model = mod)
  output[,mod$global$tnow + 1L, ] <- c(mod$aqua$L, mod$aqua$A, mod$mosquito$M)
  mod$global$tnow <- mod$global$tnow + 1L
}

model_output = list(t = seq(from=1,to=main_config$tmax+1), MYZ=output)

jsonlite::write_json(x = model_output, path = model_out, na = "null", auto_unbox=TRUE, digits=17, pretty=TRUE)
model_output_check = jsonvalidate::json_validate(model_out, model_out_schema)

if(!model_output_check){
  quit(save="no",status=1)
}

print(model_output)

quit(save="no",status=0)