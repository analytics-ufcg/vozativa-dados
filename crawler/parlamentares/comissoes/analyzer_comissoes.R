#' @title Processa dados de comissões no Senado
#' @description Processa dados de comissões no Senado
#' @param comissoes_senado_df Dataframe com os dados de comissões
#' @return Dataframe processado
processa_comissoes_senado <- function(comissoes_senado_df) {
  comissoes_senado_df <- comissoes_senado_df %>% 
    dplyr::mutate(id_senado = stringr::str_match(foto, "fotos-oficiais/senador(.*?).jpg")[,2]) %>% 
    dplyr::filter(nome != "", nome != "VAGO", id_senado != "") %>%
    dplyr::mutate(cargo = dplyr::if_else(is.na(cargo), 
                                         situacao,
                                         cargo)) %>% 
    dplyr::mutate(cargo = dplyr::if_else(cargo == "RELATOR",
                                         situacao,
                                         cargo)) %>% # Checagem adicional que irá sair quando o erro da API (Senado) for corrigido 
    dplyr::select(id = id_senado, nome, cargo, situacao, sigla, casa, data_inicio, data_fim) %>% 
    dplyr::distinct()
  
  return(comissoes_senado_df)

}

#' @title Padroniza nomenclatura do cargo de um parlamentar numa Comissão
#' @description Padroniza nomenclatura do cargo de um parlamentar numa Comissão
#' @param cargo Cargo para padronização
#' @return String com Nome Padronizado
#' @examples
#' padroniza_cargo_comissao("Titular")
padroniza_cargo_comissao <- function(cargo) {
  library(tidyverse)
  source(here::here("crawler/parlamentares/comissoes/constants/cargos.R"))
  
  cargo_padronizado = dplyr::case_when(tolower(cargo) == tolower(.PRESIDENTE) ~ "Presidente",
                                       tolower(cargo) == tolower(.VICE_PRESIDENTE) ~ "Vice-presidente",
                                       tolower(cargo) == tolower(.PRIMEIRO_VICE_PRESIDENTE) ~ "Primeiro Vice-presidente",
                                       tolower(cargo) == tolower(.SEGUNDO_VICE_PRESIDENTE) ~ "Segundo Vice-presidente",
                                       tolower(cargo) == tolower(.TERCEIRO_VICE_PRESIDENTE) ~ "Terceiro Vice-presidente",
                                       startsWith(tolower(cargo), .TITULAR) ~ "Titular",
                                       startsWith(tolower(cargo), .SUPLENTE) ~ "Suplente")
  
  return(cargo_padronizado)
}

#' @title Atribui um peso ao cargo do parlamentar na Comissão
#' @description Classifica cargos da Comissão de acordo com o nível do cargo
#' @param cargo Cargo para padronização
#' @param situacao Situação do parlamentar na Comissão
#' @return Valor atribuído ao cargo
#' @examples
#' enumera_cargo_comissao("Titular")
enumera_cargo_comissao <- function(cargo, situacao) {
  library(tidyverse)
  source(here::here("crawler/parlamentares/comissoes/constants/cargos.R"))    

  peso = dplyr::case_when(tolower(cargo) == tolower(.PRESIDENTE) ~ 7,
                          tolower(cargo) == tolower(.VICE_PRESIDENTE) ~ 6,
                          tolower(cargo) == tolower(.PRIMEIRO_VICE_PRESIDENTE) ~ 6,
                          tolower(cargo) == tolower(.SEGUNDO_VICE_PRESIDENTE) ~ 5,
                          tolower(cargo) == tolower(.TERCEIRO_VICE_PRESIDENTE) ~ 4,
                          startsWith(tolower(cargo), .TITULAR) ~ 3,
                          startsWith(tolower(cargo), .SUPLENTE) ~ 2,
                          is.na(tolower(cargo)) & situacao == .TITULAR ~ 1,
                          TRUE ~ 0)
  
  return(peso)
}

#' @title Recupera informações das Comissões e de suas composições
#' @description Retorna dados de Comissões da Câmara dos Deputados e também suas composições
#' @return Lista com dois Dataframes: comissões e composição das comissões
#' @examples
#' processa_comissoes()
processa_comissoes <- function() {
  library(tidyverse)
  library(here)
  source(here::here("crawler/parlamentares/comissoes/fetcher_comissoes.R"))
  
  comissoes <- agoradigital::fetch_all_composicao_comissao()
  
  comissao_composicao_camara <- comissoes %>% 
    filter(casa == "camara") %>% 
    mutate(is_membro_atual = !is.na(data_inicio) & is.na(data_fim))
  
  comissao_composicao_senado <- comissoes %>% 
    filter(casa == "senado") %>% 
    processa_comissoes_senado(.) %>% 
    mutate(is_membro_atual = TRUE)
  
  comissao_composicao <- comissao_composicao_camara %>% 
    bind_rows(comissao_composicao_senado)
  
  lista_comissao <- comissao_composicao %>% 
    dplyr::distinct(casa, sigla) %>% 
    tibble::as_tibble() %>% 
    dplyr::mutate(dados = purrr::map2(sigla, 
                                      casa,
                                      fetch_comissao_info)) %>% 
    tidyr::unnest(dados) %>% 
    dplyr::mutate(nome_comissao = stringr::str_to_title(nome_comissao)) %>% 
    dplyr::filter(!str_detect(toupper(nome_comissao), 'ESPECIAL'))
  
  ## Composição das Comissões
  composicao_comissoes <- comissao_composicao %>% 
    dplyr::left_join(lista_comissao, by = c("sigla", "casa")) %>% 
    dplyr::filter(!is.na(comissao_id)) %>% 
    dplyr::mutate(peso_cargo = enumera_cargo_comissao(tolower(cargo), tolower(situacao))) %>% 
    dplyr::mutate(cargo = padroniza_cargo_comissao(tolower(cargo))) %>% 
    
    dplyr::group_by(comissao_id, id) %>% 
    dplyr::mutate(maximo = max(peso_cargo)) %>%
    dplyr::filter(maximo == peso_cargo) %>%
    ungroup() %>% 
    dplyr::select(comissao_id, casa, id_parlamentar = id, cargo, situacao, data_inicio, data_fim, is_membro_atual) %>% 
    dplyr::filter(!is.na(comissao_id))

  ## Informações das Comissões
  comissoes <- lista_comissao %>%
    dplyr::select(id = comissao_id, casa, sigla, nome = nome_comissao)
  
  return(list(comissoes, composicao_comissoes))
}

#' @title Recupera informações das Comissões e de suas composições
#' @description Retorna dados de Comissões do Congresso Nacional e também suas composições
#' @return Lista com dois Dataframes: comissões e composição das comissões
#' @examples
#' processa_comissoes_composicao()
processa_comissoes_composicao <- function() {
  library(tidyverse)
  
  dados_comissoes <- processa_comissoes()
  
  comissoes <- dados_comissoes[[1]]
  composicao_comissoes <- dados_comissoes[[2]]
  
  return(list(comissoes, composicao_comissoes))
}
