/**
 * Schema for Beverton-Holt aquatic mosquito model in MicroMoB
 */
export interface AdultPar {
  stochastic: boolean[]
  molt: number[]
  surv: number[]
  K: number[]
  L: number[]
}