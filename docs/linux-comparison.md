# Comparação com o driver Linux oficial v1.2.3

Análise em 28/10/2026 do pacote indicado pelo Download Center da Elgin para i9 Full. A unidade deste projeto foi identificada pelo proprietário como i9 FULL2; o pacote oficial usa apenas i9/i9 Full, portanto a análise não certifica todas as revisões.

Fonte: https://www.elgin.com.br/download-center-product?id=39092b4d-3dbe-462a-aa95-ba5e806aeaaa&categoryId=28

Pacote: https://content.elgin.com.br/assets/arquivos/portal-apoio-novo/15d35782-b16b-40ad-bd0b-a899138e1402.zip

SHA-256 do ZIP analisado: `297fa8cbb2a4de92df2119b0e10055338d4827dd0fcc64bfd2ffa0e5d6f0c5c4`.

O pacote contém PPDs i7/i8/i9/rm22, instaladores e filtros rastertohprt binários x86/x64 para Linux. Não contém código-fonte do filtro. Nenhum instalador ou executável do pacote foi executado ou incorporado a este projeto.

| Parâmetro | Linux oficial (PPD i9) | Projeto macOS | Conclusão |
|---|---|---|---|
| Resolução | 203 × 203 dpi | 203 × 203 dpi | Coincide |
| Página padrão | Roll80mm, PageSize 204 × 842 pt | 72mmx297mm, 204 × 842 pt | Mesma geometria; 80 mm é nome da bobina |
| Área útil | 0 0 204 842 pt | 0 0 204 842 pt | Coincide; não ampliar para 80 mm úteis |
| Rasterização | 1 bit por cor, espaço K | Cinza 8 bits convertido pelo filtro a 1 bit | Cadeias diferentes; não copiar a resolução do PPD Linux diretamente |
| Corte | Parcial; ação por trabalho ou por página | Parcial padrão; total e sem corte; processado por página | Corte final do trabalho é melhoria possível; corte total não é anunciado pelo PPD oficial i9 e permanece sem validação física aqui |
| Avanço | 0–30 mm em passos de 5 mm para alimentação/corte | 24 linhas raster finais e comando de corte com avanço 0; sem corte usa ESC d 4 | Parâmetro de avanço explícito é melhoria possível, com teste físico |
| Economizar branco final | Ativado por padrão | Recorte de margens ativo por padrão | Objetivo semelhante; algoritmos não comparáveis sem fonte Linux |
| Redução de papel | 25%, 50%, 75% | Ajuste proporcional à largura; sem percentuais específicos | Funções diferentes; reduzir altura pode deformar códigos e texto |
| Logotipo na memória | Índice 0–9, início/fim e alinhamento | Não implementado; imagens do documento são rasterizadas | Exige documentação dos comandos e teste |
| Buzzer interno/externo | Momento, duração, intervalo, repetições | Não implementado | Depende de suporte da unidade e comandos documentados |
| Gavetas 1 e 2 | Abrir antes/depois | Não implementado | Exige validar pulsos e pinagem; não deduzir só pelo PPD |
| Compressão bitmap | Opção, desativada por padrão | Não implementada | Não copiar sem conhecer o formato esperado pelo filtro/firmware |
| Centralização calibrada | Nenhuma opção equivalente no PPD | ElginShift=12 padrão, ajustável | Ajuste específico da unidade testada; preservar |
| Envio em blocos | Não descrito pelo PPD | 64 linhas, 30 ms padrão | Sem fonte do filtro Linux não é possível comparar o transporte |

## Resultado

Não há evidência de que seja necessário mudar largura, resolução ou margens padrão: a geometria oficial coincide com a nossa. Esta comparação não modificou o filtro nem a impressora instalada.

Melhorias prioritárias para uma próxima implementação: avanço configurável em milímetros, seleção de corte por página ou ao final do trabalho e opção separada de economia de branco final sem redimensionamento. Cada uma exige implementação real no filtro e teste de saída; o PPD sozinho só descreve a interface.

O PPD oficial expõe apenas corte parcial para i9. Não se deve anunciar corte total como validado com base nesta análise. A transformação por escala do nosso filtro também não garante leitura de todo QR/barcode; valide o cupom com leitor real.

Os demais recursos são opcionais e não justificam mudar os padrões que já funcionaram na unidade testada. O pacote proprietário não é redistribuído neste repositório.
