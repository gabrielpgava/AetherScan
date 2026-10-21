# AetherScan

**The Spectral Wi-Fi Inspector for macOS** — um utilitário nativo para visualizar redes próximas, comparar a ocupação dos canais e identificar conflitos.

## Requisitos

- macOS 13 Ventura ou posterior
- Xcode 15 ou posterior (ou Command Line Tools compatíveis)
- Wi-Fi ativo; o acesso à Localização é necessário para que o macOS exponha SSIDs e BSSIDs

## Compilar e executar pelo Terminal

Na raiz do repositório, use o Makefile:

```sh
make build    # compila Debug (também é o alvo padrão: make)
make release  # compila Release
make run      # compila Debug e abre o app
make icon     # regenera o ícone do app e os tamanhos Retina
make clean    # limpa os produtos Debug e Release
```

Os produtos ficam em `build/DerivedData/Build/Products/`. Para abrir o projeto no Xcode pelo Terminal, use `make xcode`. O Makefile também aceita ajustes como `make build DESTINATION="platform=macOS,arch=arm64"`.

Na primeira abertura, permita o acesso à Localização para ver nomes e BSSIDs das redes. A varredura começa automaticamente; depois, use **Atualizar** ou `⌘R` para repetir.

## Abrir no Xcode

Abra `AetherScan.xcodeproj`, selecione o scheme **AetherScan**, escolha **My Mac** e pressione **Run** (`⌘R`). O texto de uso da Localização já está incluído em `AetherScan/Info.plist` e localizado em português e inglês.

Se a permissão for negada, abra **Ajustes do Sistema → Privacidade e Segurança → Serviços de Localização**, permita o acesso ao AetherScan e volte ao app.

## O que a análise mostra

- SSID, BSSID, faixa, canal, frequência, largura de canal e RSSI, quando disponibilizados por CoreWLAN.
- Compartilhamento de canal e sobreposição de canais adjacentes em 2,4 GHz.
- Recomendações de canais 1/6/11 em 2,4 GHz e dos canais de 5 GHz compatíveis com o Mac e com menor ocupação estimada entre as redes visíveis.

As recomendações são estimativas da varredura Wi-Fi local. Elas não substituem uma análise de interferência de rádio não-Wi-Fi, e os dados disponíveis variam por hardware, região e permissões do macOS.
