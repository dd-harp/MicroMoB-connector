/**
 * Schema for Ross-Macdonald adult mosquito model in MicroMoB
 */
export interface AdultPar {
  stochastic: boolean[]
  f: number[]
  q: number[]
  eip: number[]
  p: number[]
  psi: number[][]
  nu: number[]
  M: number[]
  Y: number[]
  Z: number[]
}