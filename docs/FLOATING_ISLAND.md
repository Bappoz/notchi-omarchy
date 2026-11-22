# Ilha flutuante

A instância do widget fornece o monitor e um atalho na barra. O `PanelWindow`
de `Notch.qml` posiciona a cápsula no centro da tela a 8 px da borda superior e
restringe a região de entrada à ilha e ao menu. As animações abrem a mesma
superfície mantendo posição e escala coerentes durante a transição. Os perfis 3D
transformam uma captura da superfície visual. O plano de entrada permanece fixo.

| Estado | Comportamento | Como conferir |
| --- | --- | --- |
| Repouso | Hora e dia, com a cápsula no topo | Feche a ilha e pause o player. Após o último sinal expirar, sobra o relógio |
| Compacto | Onda de mídia, mascotes dos provedores ativos, contador de tempo ou último sinal | Toque uma faixa MPRIS, observe um agente executando e inicie um timer em Foco. Mídia e mascotes podem aparecer juntos, com o relógio no centro |
| Alerta | Texto curto, ícone em movimento e retorno automático | Envie os eventos de teste abaixo. Chamadas podem antecipar outro aviso. Depois da transição, o ícone mais recente pode ficar visível por até cinco minutos |
| Expandido | Título, artista e transporte MPRIS, atalhos de Foco, Tarefas e Agentes, mais o cronômetro | Passe o mouse e saia da cápsula. Clique para fixar, navegue pelo menu e feche com Esc ou clique fora |

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
- **Wi‑Fi e fones Bluetooth.** Notifica novas conexões confirmadas pelo
  NetworkManager e por dispositivos de áudio conectados no BlueZ. O primeiro
  estado observado é a referência. Os avisos mostram um ícone à esquerda e um
  aro de confirmação à direita. Os nomes das redes e dos dispositivos ficam
  fora da ilha. A verificação ocorre a cada três segundos, com fallback
  silencioso quando a fonte está indisponível.
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
detalhes de provedor, movimento reduzido e reprodução/pausa.

As imagens abaixo são capturas do QML com dados sintéticos. [Claude e Codex em atividade](../screenshots/island-agents.png) · [Wi-Fi conectado](../screenshots/island-wifi.png) · [Fones conectados](../screenshots/island-headphones.png).

| Repouso | Reprodução | Chamada |
| --- | --- | --- |
| ![Relógio e dia](../screenshots/island-idle.png) | ![Onda em reprodução](../screenshots/island-playing.png) | ![Chamada do Discord](../screenshots/island-alert.png) |

Clientes de mídia. [spotify-player](https://github.com/aome510/spotify-player) · [Spotifast](https://github.com/crmne/spotifast)

Referências de composição e comportamento. [Apple WidgetKit](https://developer.apple.com/documentation/widgetkit/dynamicisland) · [Referência compartilhada no Figma](https://www.figma.com/community/file/1218911785891720138/dynamic-island-navigation-bbar) · [Omdrop](https://github.com/netmojo-systems/omdrop-plugin) · [ElecWhat](https://github.com/piec/elecwhat/)
