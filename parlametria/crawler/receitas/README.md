### Receitas durante as eleições de 2018

Este módulo é responsável por capturar e processar dados de receitas recebidas pelos candidatos durante as eleições de 2018 para Deputado Federal e Senador.

Alguns componentes deste módulo são:

- Script para captura dos dados no site do TSE: `./fetcher_receitas_tse.sh`
- Funções para processamento dos dados presentes no arquivo: `analyzer_receitas_tse.R`. Dentre elas:
    - `processa_doacoes_partidarias_tse` que processa dados de doações feitas pelo partido ao candidato; 
    - `processa_doacoes_tse` que processa todas as doações feitas ao candidato durante as eleições de 2018; 
    - `processa_doacoes_parlamentares_tse` cruza as informações de doações com a lista atual de parlamentares em exercício (até a data de atualização do arquivo crawler/raw_data/parlamentares.csv).
- Script para exportação dos dados de receita originárias de doações do partido para os candidatos: `export_receitas_tse.R`
- Script para exportação dos dados de receita recebidas em 2018 por deputados e senadores em exercício (até a data de atualização do arquivo crawler/raw_data/parlamentares.csv): `export_doacoes_campanha.R`

