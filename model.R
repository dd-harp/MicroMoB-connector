library(MicroMoB)
library(jsonlite) 
library(jsonvalidate)
library(rstudioapi)

ARGS <- commandArgs(trailingOnly=TRUE)
print(ARGS)
# IO
if(length(ARGS)>1){
  model_input_fn = ARGS[1]
  model_output_fn = ARGS[2]
  model_input_schema_fn = ARGS[3]
  model_output_schema_fn = ARGS[4]
} else {
  model_input_fn = "test/input.json"
  model_output_fn = "output/data.json"
  model_input_schema_fn = "schema/input.json"
  model_output_schema_fn = "schema/output.json"
}


input_check <- jsonvalidate::json_validate(json = model_input_fn, schema = model_input_schema_fn)
if(!input_check){
  quit(save = "no", status = 1)
}

input <- jsonlite::read_json(path = model_input_fn, simplifyVector = TRUE)

# create model object
mod <- MicroMoB::make_MicroMoB(tmax = input$tmax, p = input$p)

# setup adult mosquito
MicroMoB::setup_mosquito_RM(
  model = mod,
  stochastic = input$adult_stochastic,
  f = input$adult_f,
  q = input$adult_q,
  eip = input$adult_eip,
  p = input$adult_p,
  psi = input$adult_psi,
  nu = input$adult_nu,
  M = input$adult_M,
  Y = input$adult_Y,
  Z = input$adult_Z
)

# setup aquatic mosquito
MicroMoB::setup_aqua_BH(
  model = mod,
  stochastic = input$aqua_stochastic,
  molt = input$aqua_molt, 
  surv = input$aqua_surv,
  K = input$aqua_K,
  L = input$aqua_L
)

# output is stored in an array (patches X timesteps X life stages)
output <- array(NaN, dim = c(input$p, input$tmax + 1, 3))
output[, 1, ] <- c(mod$aqua$L, mod$aqua$A, mod$mosquito$M)

# run simulation
while (mod$global$tnow <= input$tmax) {
  MicroMoB::step_aqua(model = mod)
  MicroMoB::step_mosquitoes(model = mod)
  output[,mod$global$tnow + 1L, ] <- c(mod$aqua$L, mod$aqua$A, mod$mosquito$M)
  mod$global$tnow <- mod$global$tnow + 1L
}

model_output = list(metadata = input, t = seq(from = 1, to = input$tmax + 1), MYZ = output)

jsonlite::write_json(x = model_output, path = model_output_fn, na = "null", auto_unbox = FALSE, digits = 17, pretty = TRUE)
model_output_check = jsonvalidate::json_validate(json = model_output_fn, schema = model_output_schema_fn)

if(!model_output_check){
  quit(save="no",status=1)
}

print(model_output)

quit(save="no",status=0)