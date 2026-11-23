# Ilha flutuante

A instância do widget fornece o monitor e um atalho na barra. O `PanelWindow`
de `Notch.qml` posiciona a cápsula no centro da tela. Em repouso ela mede
32 px de altura com 6 px de margem superior. A janela restringe a região de
entrada à ilha e ao menu. As animações abrem a mesma
superfície mantendo posição e escala coerentes durante a transição. Os perfis 3D
transformam uma captura da superfície visual. O plano de entrada permanece fixo.

| Estado | Comportamento | Como conferir |
| --- | --- | --- |
| Repouso | Hora no centro da cápsula e calendário discreto à esquerda quando não há mascotes ativos | Feche a ilha e pause o player. Após o último sinal expirar, sobra o relógio |
| Compacto | Onda de mídia, mascotes dos provedores ativos, contador de tempo ou último sinal | Toque uma faixa MPRIS, observe um agente executando e inicie um timer em Foco. Mídia e mascotes podem aparecer juntos, com o relógio no centro |
| Alerta | Texto curto, ícone em movimento e retorno automático | Envie os eventos de teste abaixo. Chamadas podem antecipar outro aviso. Depois da transição, o ícone mais recente pode ficar visível por até cinco minutos |
| Expandido | Título, artista e controles MPRIS, cronômetro e dock inferior | Passe o mouse e saia da cápsula. Clique para fixar, navegue pelo dock e feche com Esc ou clique fora |

**Ajustes → Aparência** mantém os nove perfis de abertura. `Fluid Classic` é o
perfil padrão. Desative **Animações** para conferir que a geometria, o sino,
o contorno e a onda ficam estáticos. O contorno acompanha mídia e agentes ativos, com uma passagem breve para novos avisos. O cronômetro é local ao processo do shell e
pode ser pausado, retomado e zerado. O timer de Foco conserva o agendamento e
a entrega por systemd.

## Fontes de eventos

- **Mídia.** Usa MPRIS da sessão. Spotify e clientes de terminal aparecem
  quando o cliente ou seu bridge publica um player MPRIS. Para conferir a
  publicação, use `playerctl -l` se o utilitário estiver instalado. A onda é um indicador
  animado de reprodução e independe da captura de áudio.
- **Agentes.** Usa os metadados locais de Claude Code e Codex disponíveis em
  `telemetry.py`. A amostra inicial só estabelece a referência. Os avisos de
  conclusão e atenção dependem dos estados que os clientes registram.
- **Desktop.** Ative **Alertas do desktop** em Aparência. O adaptador local
  requer `/usr/bin/python3`, `python-gobject` e permissão do barramento de
  sessão para observar o método freedesktop `Notify`. Ele usa o nome do app,
  a categoria e, para classificação, parte do título. Só o tipo e um rótulo
  fixo chegam ao QML. Mensagens, ações e caminhos de arquivos ficam fora da
  ilha. O identificador do executável na ação padrão do Omarchy também serve
  para classificar avisos de arquivo recebido do Omdrop. O serviço de notificações do desktop mantém a entrega e as ações
  originais. O adaptador respeita o Não Perturbe do Omarchy quando o estado
  `notifications/quiet.json` está disponível.
- **Chamadas e transferências.** WhatsApp/ElecWhat e Discord/Vesktop são
  classificados por categoria de chamada ou por títulos reconhecidos em
  português e inglês. Omdrop/AirDrop e LocalSend usam a identificação da
  notificação. A cobertura varia com o cliente e com sua configuração de
  notificações. Atender chamadas, aceitar transferências e exibir progresso
  dependem do aplicativo de origem.
- **Volume.** O painel de OSD recebe as teclas e os controles do Omarchy.
  Alterações externas também são observadas no sink padrão do PipeWire. O
  primeiro valor estabelece uma referência. Brilho e avisos do sistema
  continuam aparecendo na parte inferior.
- **Silêncio das notificações.** O atalho padrão **Super + Ctrl + Alt + ,**
  alterna o Não Perturbe do Omarchy. O Notchi acompanha o estado gravado pelo
  serviço de notificações e só anima mudanças depois da leitura inicial.
  A confirmação funciona mesmo com **Alertas do desktop** desativado.
- **Câmera.** A luz verde acompanha fontes V4L2/libcamera ativas no PipeWire
  e processos do usuário com descritores V4L2 abertos. O plugin lê apenas
  metadados. O uso direto de V4L2 é uma aproximação, pois um programa pode
  manter o dispositivo aberto sem captar imagens.
- **Bateria.** O UPower informa a conexão à energia, a passagem para 20% e a
  conclusão da carga. Uma amostra inicial já carregada ou descarregada serve
  de referência.
- **Wi‑Fi e Bluetooth.** A consulta usa NetworkManager e BlueZ a cada três
  segundos. A ilha mostra o nome local do dispositivo Bluetooth e o nível
  da bateria se o BlueZ o publicar. No BlueZ padrão, o nível disponível é
  agregado. Esquerda, direita e estojo dependem do fabricante e do driver.
- **Voz.** O atalho grava até 12 segundos e mede a intensidade do áudio para
  animar as barras. A gravação temporária vai para a CLI do Superwhisper sem
  inserção de texto no aplicativo ativo. O arquivo fica disponível até a
  sessão de transcrição terminar e depois é removido. O modo escolhido no Superwhisper
  determina se o áudio é processado localmente ou na nuvem. O Cursor Buddy
  é um indicador visual e acompanha a janela identificada pelo Hyprland.
  Aplicativos com um identificador de janela diferente do arquivo .desktop
  podem abrir sem o cursor animado.
- **Builds, deploys e scripts.** Use o IPC local com um tipo fixo. A resposta
  `queued` indica aceitação para a fila. `ignored` indica sessão
  indisponível ou evento repetido.

```sh
omarchy-shell bappoz.notch.service event report
omarchy-shell bappoz.notch.service event attention
omarchy-shell bappoz.notch.service event transfer
omarchy-shell bappoz.notch.service event call
omarchy-shell bappoz.notch status
```

Para conferir o classificador sem entrar em uma chamada ou compartilhar arquivos,
use alertas sintéticos depois de habilitar a integração.

```sh
notify-send -a Vesktop -c call.incoming "Chamada de teste"
notify-send -a Omdrop "Transferência de teste"
```

A fila compartilhada tem quatro posições, deduplica avisos próximos e descarta
pendências após 16 segundos. Chamadas, atenção e timer precedem avisos de
rotina. A ilha recebe avisos no monitor em foco quando o painel está fechado.
Perda de confirmação de sessão ativa ou lacuna no relógio de eventos limpa a
fila. Em sistemas sem confirmação do login, relógio, mídia e navegação continuam
disponíveis.

## Validação

```sh
omarchy plugin validate .
python -m unittest discover -s tests
dbus-run-session -- /usr/bin/python3 tests/island_dbus_probe.py
NOTCHI_UI_TESTS=1 dbus-run-session -- python -m unittest discover -s tests
```

Execute a última linha em um perfil Wayland descartável. O teste de interface
usa um player MPRIS sintético e a variável `NOTCHI_CAPTURE_DIR` para capturas.
Ele percorre os nove perfis, saída por hover, navegação fixada, retorno de
detalhes de provedor, movimento reduzido e reprodução/pausa. Também exercita
o mini calendário, os atalhos em Ajustes, as mensagens de OSD, eventos de hardware simulados e um comando de voz que
abre o calendário, sem usar microfone nem serviços externos. As capturas
`hardware-*.png` e `updated-*.png` mostram os cenários novos.

As imagens abaixo são capturas do QML com dados sintéticos. [Claude e Codex em atividade](../screenshots/island-agents.png) · [Wi-Fi conectado](../screenshots/island-wifi.png) · [Fones conectados](../screenshots/island-headphones.png).

| Repouso | Reprodução | Chamada |
| --- | --- | --- |
| ![Relógio e dia](../screenshots/island-idle.png) | ![Onda em reprodução](../screenshots/island-playing.png) | ![Chamada do Discord](../screenshots/island-alert.png) |

Clientes de mídia. [spotify-player](https://github.com/aome510/spotify-player) · [Spotifast](https://github.com/crmne/spotifast)

Referências de composição e comportamento. [Apple WidgetKit](https://developer.apple.com/documentation/widgetkit/dynamicisland) · [Referência compartilhada no Figma](https://www.figma.com/community/file/1218911785891720138/dynamic-island-navigation-bbar) · [Omdrop](https://github.com/netmojo-systems/omdrop-plugin) · [ElecWhat](https://github.com/piec/elecwhat/)
