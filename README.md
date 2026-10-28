# Elgin i9 — driver comunitário para macOS

Driver CUPS independente para impressão de imagens, PDFs e cupons na Elgin i9 por rede Ethernet (ESC/POS, TCP 9100). Criado e ajustado com teste físico de impressão em uma i9. Não é um driver oficial da Elgin e não contém código do driver Windows.

## Instalação

1. Baixe o ZIP na seção **Releases** e descompacte.
2. Instale as ferramentas de compilação da Apple, se necessário: `xcode-select --install`.
3. Abra **Instalar.command**, informe o IP da sua impressora e digite a senha de administrador no Terminal. A senha não aparece enquanto você digita.
4. Feche e reabra o aplicativo de impressão. Selecione **Elgin i9** e papel **72 mm × 297 mm**.

Se o macOS bloquear a abertura do arquivo baixado, use o Terminal na pasta extraída:

```sh
sh install.sh 192.168.1.100
```

Substitua o IP pelo da sua impressora. A instalação compila para a arquitetura do próprio Mac; requer macOS com suporte a filtros CUPS/PPD, cabeçalhos CUPS e Command Line Tools da Apple. A compatibilidade foi verificada apenas no Mac desta sessão (macOS 27.0.1); outras versões e modelos precisam de validação. Não exige Homebrew. Não inclui pacote `.pkg` assinado ou notarizado.

## Configuração e limites

- Bobina física de aproximadamente 79–80 mm; área nominal de impressão de 72 mm (576 pontos a 203 dpi).
- Recorta margens brancas e ajusta o conteúdo proporcionalmente. Isso altera a escala; para dimensões exatas, desative o ajuste.
- Centralização padrão de 12 pontos, calibrada numa unidade com margens físicas de 5 mm e 2 mm. Outras unidades podem exigir ajuste.
- Corte parcial padrão; opções de corte total ou sem corte.
- Blocos de 64 linhas com pausa de 30 ms. Ajustes disponíveis nas opções da impressora.
- Conversão por limiar preto/branco: não usa dithering. Cinzas claros podem desaparecer.
- O tamanho padrão é 72 × 297 mm. Cupons maiores exigem altura personalizada e configuração correta no aplicativo; o filtro não recupera conteúdo cortado antes da rasterização.
- Suporte documentado apenas por rede Ethernet; USB não foi validado.
- O macOS avisa que drivers tradicionais serão descontinuados. A instalação depende de esse recurso continuar disponível.

Teste com um PDF real:

```sh
lp -d ELGIN_I9 '/caminho/real/cupom.pdf'
```

Opções disponíveis:

```sh
lpoptions -p ELGIN_I9 -l
lpoptions -p ELGIN_I9 -o ElginShift=0 -o ElginFit=None
lpoptions -p ELGIN_I9 -o ElginShift=12 -o ElginFit=Content
```

Se houver impressão incompleta, experimente `ElginBand=24` e `ElginDelay=200`. Pausas no filtro não garantem controle de fluxo de rede. Se houver impressão inesperada, cancele com `cancel -a ELGIN_I9`.

## Remover

Na pasta do projeto, execute `sh uninstall.sh`. Isso remove somente a fila ELGIN_I9 e os dois arquivos instalados por este projeto.

## Código e contribuições

`rastertoelgini9.c` converte CUPS Raster cinza de 8 bits ou RGB de 24 bits para bandas ESC/POS GS v 0. `ElginI9.ppd` define os tamanhos e opções. `install.sh` compila localmente e instala os arquivos em `/Library/Printers/Elgin/i9`.

Relate problemas incluindo versão do macOS, modelo da impressora, opções e uma amostra sem dados pessoais. Não envie senhas ou documentos com dados reais de clientes.

Licença MIT. Elgin é marca de seu respectivo titular.
