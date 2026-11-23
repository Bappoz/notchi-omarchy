# Notchi for Omarchy

Ilha dinâmica nativa para o shell do Omarchy, inspirada em [OpenNotchi, de nannndev](https://github.com/nannndev/OpenNotchi). Adaptação independente para Linux/Wayland, em QML/Quickshell, sob licença MIT. A superfície flutuante usa geometria e transições próprias em QML. As telas detalhadas mantêm a linhagem do OpenNotchi. Logos de provedores vêm do repositório; os vetores Lucide vêm da mesma biblioteca da versão Windows. Os créditos e as licenças estão preservados. Third-party sources and licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

[Versão 0.8.0](https://github.com/Bappoz/notchi-omarchy/releases/tag/v0.8.0) · [Instalação e atualização](#instalar-e-atualizar) · [Histórico de versões](CHANGELOG.md)

![Notchi com os controles de mídia abertos](screenshots/island-media.png)

## Usar

- Passe o mouse sobre a cápsula no topo para abrir a ilha com os atalhos na parte inferior. Um clique abre e fixa a ilha no monitor em foco. Se configurado, **Super + Alt + N** também abre a ilha. **Esc** fecha.
- A roda do mouse sobre a cápsula ajusta o volume. Em repouso, a cápsula mede 32 px de altura e fica a 6 px da borda superior.
- **Super + Ctrl + Alt + ,** alterna o modo silencioso das notificações no Omarchy. A ilha mostra o sino e confirma o novo estado.
- Clique no calendário discreto à esquerda da hora para abrir o mês, com um ponto no dia de hoje.
- A engrenagem reúne aparência, integrações, atalhos e controles. Clique nela de novo para voltar à página anterior. **Ctrl + 1 … 8** mantém os atalhos das seções.
- As teclas de volume e a roda do mouse mostram o nível na ilha. A câmera em uso mantém um sinal verde. A ilha também avisa sobre conexão Bluetooth, início de carga, bateria a 20% ou menos e carga completa.
- O microfone no dock ou **Super + Alt + V**, se configurado, inicia um comando de voz. Espere aparecer **Ouvindo…**, fale e acione o mesmo controle para enviar.
- Ative **Ajustes → Aparência → Alertas do desktop** para chamadas, notificações e transferências. Para exemplos sem contas reais e a matriz de validação, veja [Ilha flutuante](docs/FLOATING_ISLAND.md).

## Tela de bloqueio

Com o [Lock Explorer](https://github.com/sirjul1337/omarchy-lock-explorer)
ativo como serviço de bloqueio, copie o tema opcional do Notchi para a pasta
de temas personalizados. Execute os comandos abaixo na raiz do repositório.

```sh
mkdir -p ~/.config/omarchy/lock-designs
cp extras/lock-designs/Notchi.qml ~/.config/omarchy/lock-designs/Notchi.qml
omarchy shell lock rescanDesigns
omarchy shell lock designs
omarchy shell lock setDesign my-notchi
omarchy shell lock setUnlockAnimation fade
```

O Notchi fica no topo, fechado em um círculo. Digite a senha ou clique no
cadeado para revelar o campo. **Super + Ctrl + L** aciona o bloqueio do Omarchy.
Após a autenticação pelo Lock Explorer, a cápsula se alarga e o cadeado abre.

## O que está incluído

| Área | Disponível nesta versão |
| --- | --- |
| Aparência | Cápsula centralizada, três aparências e nove perfis de abertura (seis 2D e três 3D). Respeita as animações desligadas no Omarchy |
| Monitores | Uma ilha em cada tela; atalho abre no monitor em foco |
| Mídia | Fontes MPRIS, capa, vinil giratório, reproduzir/pausar, anterior/próxima, seek, shuffle/repeat quando o player expõe esses controles; volume e mute |
| Vídeo | Prévia ao vivo de uma janela escolhida; algumas janelas minimizadas não fornecem imagens ao compositor |
| Letras | Abrir Letras inicia a consulta ao LRCLIB; envia artista, título, álbum e duração. Trocas de faixa atualizam a letra somente enquanto a tela está aberta. Aceita letras sem sincronia e arquivos LRC |
| Agenda | Hora centralizada, mini calendário na cápsula, relógios de São Paulo/Londres/Dubai/Tóquio/Los Angeles, acesso ao calendário completo e ao globo originais |
| Reuniões | Acesso ao plugin existente de próximos eventos; o feed e sua configuração são preservados |
| Foco | Cronômetro na sessão do shell, timer com presets, duração e mensagem personalizadas; alerta entregue pelo systemd mesmo com o painel fechado ou recarregado |
| Arquivos | Soltar arquivos ou escolher pela janela de seleção; abrir, revelar, arrastar para fora, remover referência, OCR e conversão PNG/JPEG/WebP |
| Clipboard | Histórico já existente do Omarchy, busca e cópia de texto/imagens; sem instalar outro capturador de clipboard |
| Câmera | Prévia iniciada por botão, 18 estilos e quatro opções de moldura com seletores circulares e prévia ao vivo, fotos e desenho livre; originais preservados. Fecha o painel para desligar |
| Agentes | Cartões clicáveis com tokens de hoje, histórico diário e modelos quando reportados; cotas de uso consumido, atualizadas pelos coletores nativos a cada cinco minutos, horário/estado da leitura e atualização manual. Sessões Claude/Codex com atividade, projeto, workspace identificado, tokens e contexto quando reportados |
| HUDs | Volume e mudo na ilha, indicação de câmera em uso e avisos para Bluetooth, começo da carga, bateria baixa e carga concluída |
| Voz | Superwhisper para Linux, medidor do microfone e Cursor Buddy para apontar para janelas reconhecidas pelo Hyprland |
| Sistema | CPU, memória, disco, tráfego de rede com histórico e bateria do notebook |
| Controles locais | CPU, memória, baterias que o kernel expõe, saídas de áudio, portas TCP, encerramento confirmado de processo próprio, seletor de cor, brilho, captura de texto |
| Omarchy | Gravação/parada, lembretes, luz noturna, não perturbe, manter acordado, teclado, atualizações, Bluetooth e acesso administrativo temporário pelos comandos originais |
| Clima | Cena animada, temperatura e sensação, umidade, vento e previsão por hora via Open-Meteo; avisos breves por mudança observada, compartilhando a fila dos agentes |
| Tarefas | Lista diária local com notas, prioridades, conclusão, reordenação, desfazer exclusão e seis cores |
| Mercados | Câmbio de referência via Frankfurter, cripto via CoinGecko, ações via Alpha Vantage com chave própria |
| Casa | Conector Home Assistant: luzes, dimmer, tomadas, cenas e termostatos/modos; requer URL e token próprios |
| Spotify Connect | Listar dispositivos e transferir reprodução; requer token próprio com permissões adequadas e conta compatível |
| Orações | Cálculo offline com PrayTime, método/localização configuráveis e avisos para os horários restantes de hoje |

## Tarefas, clima e detalhes de IA

As tarefas ficam somente neste computador, em `~/.local/state/omarchy-notch/state.json`. Clique no título para editar detalhes e prioridade; use as setas para ordenar, o círculo para concluir e a lixeira para excluir. O botão Desfazer recupera a última exclusão. O histórico mantém as tarefas concluídas de dias anteriores.

Clique num provedor em IA para ver os contadores locais e gráficos de 7/30 dias. Os coletores podem fornecer apenas parte desse histórico. Campos ausentes permanecem desconhecidos, e os totais por modelo cobrem todo o histórico disponível, sem equivaler à cota da assinatura nem a uma fatura.

A aba Clima reutiliza a localização configurada no Omarchy ou nas integrações. O botão de localização abre o painel original. A consulta ocorre a cada dez minutos, com verificação local da sessão a cada minuto. O carregamento inicial e as trocas de localização estabelecem uma nova referência. A fila expira ao suspender ou quando a sessão fica indisponível. Chuva, tempestade, neve e umidade ≤25% avisam na mudança de condição; temperatura avisa para variação ≥3°C, com intervalo mínimo de 45 minutos. São avisos de condições previstas pelo Open-Meteo, não alertas oficiais de defesa civil. Cada aviso dura cerca de cinco segundos. Avisos de clima aguardam a fila e expiram se o painel permanecer aberto.

## Atividade e privacidade

A atividade é lida de metadados dos arquivos locais de sessão de Claude Code e Codex. O leitor é limitado por tamanho e guarda somente projeto, estado, modelo e contagens, sem prompts, respostas, ferramentas ou credenciais. Não há envio desses dados para serviços externos. O leitor consulta as sessões a cada 2,5 segundos; nenhuma geração de IA é iniciada. A atualização de cotas usa os coletores já instalados e pode consultar os provedores autenticados a cada cinco minutos ou ao clicar em Atualizar.

Tokens são o consumo reportado do turno/sessão, não um cálculo de custo. Contexto mostra a última contagem reportada; um limite não informado permanece desconhecido. Workspace é associado pela árvore de processos e janela; se não houver associação única, aparece `—`. O estado combina eventos de ferramentas/turnos com os registros locais de processos de Claude (`~/.claude/sessions`), verificando PID e início do processo. Um comando pendente aparece como Monitorando; um agente em espera permanece separado de um agente ativo. Processos Claude vivos continuam listados mesmo se o transcript ficar sem atualizações por mais de 30 minutos. Sem evidência de processo vivo, cinco minutos sem eventos mudam a atividade para não confirmada. Sessões Antigravity e outros agentes ainda não são monitoradas nesta versão; suas cotas continuam disponíveis.

## Recursos que ainda não têm equivalência completa

A interface foi adaptada para Qt e Hyprland. Alguns recursos dependem do que o Linux, o dispositivo ou o aplicativo expõem.

- O compartilhamento usa o **LocalSend** quando instalado. O Omdrop pode gerar um aviso de transferência separado.
- O BlueZ informa a bateria de alguns dispositivos Bluetooth. No BlueZ padrão o nível é agregado, inclusive para fones cujo aplicativo próprio mostra porcentagens por lado e estojo.
- Os nove perfis foram adaptados para Qt, incluindo transformação em perspectiva, blur e escurecimento nos três efeitos 3D. A refração nativa de Liquid Glass do macOS não está disponível no Hyprland; vidro usa transparência, contorno e blur do compositor.
- Letras usam timestamps, foco/rolagem por linha e blur nas linhas distantes; o alinhamento depende dos dados LRC recebidos.
- Os estilos têm prévia em GPU e exportação não destrutiva. O processamento da foto em resolução completa pode produzir pequenas diferenças em relação à prévia. O editor oferece três decorações e desenho, sem todo o catálogo de adesivos do projeto original.
- Favoritar faixas e controle remoto completo do Spotify ficam no cliente original; o conector desta versão transfere reprodução entre dispositivos. Tokens inseridos manualmente precisam ser renovados quando expirarem.
- OCR de PDF usa **a primeira página**. Para documentos maiores, use o aplicativo de OCR/PDF de sua preferência.
- Os relógios usam um conjunto inicial de cidades. A edição visual das cidades continua disponível no globo original.

Os conectores autenticados foram validados com testes isolados, **sem conexão à conta/dispositivos do usuário**, pois nenhuma credencial foi fornecida. A câmera foi carregada com captura desligada; a captura real depende do dispositivo e de sua permissão.

## Conectar serviços opcionais

Abra **Ajustes → Conectar integrações**. Preencha somente os serviços que deseja usar. Os campos de chave vazios preservam chaves já salvas; nenhuma chave salva é devolvida à interface. Elas ficam em um arquivo privado deste computador, com permissão de leitura/escrita apenas para seu usuário.

Em **Ajustes → Atalhos e controles → Controles → Integrações**, escolha o serviço e clique **Atualizar**. As consultas extras não rodam em segundo plano. Oração é calculada offline. A opção de avisos programa somente os horários restantes **do dia atual**.

O token Home Assistant é um long-lived access token do seu perfil. Para Spotify Connect, o token precisa de `user-read-playback-state` e `user-modify-playback-state`; a disponibilidade também depende das regras do Spotify. Este plugin não implementa login OAuth nem renovação automática.

## Instalar e atualizar

O plugin usa o shell Quickshell do Omarchy com Hyprland e Python 3. A versão 0.7.0 foi validada no Omarchy 4.5.0 e no Quickshell 0.3.2 distribuído pelo Omarchy. A integração do volume depende do mecanismo de substituição de OSD do shell.

### Primeira instalação em outro computador

```sh
omarchy plugin add https://github.com/Bappoz/notchi-omarchy --enable
```

O comando instala pelo Git e adiciona o widget à barra. Você pode mudar sua posição nas configurações da barra do Omarchy. Abra o Notchi pelo widget ou passe o mouse sobre a cápsula no topo.

### Atualização de uma instalação existente

Para uma instalação feita com `omarchy plugin add`, execute:

```sh
omarchy plugin update bappoz.notch
```

O gerenciador busca a branch padrão no GitHub, mostra o diff e pede confirmação. Se estiver migrando de 0.6.3 ou anterior, carregue a nova entrada do OSD e ative a substituição uma vez:

```sh
omarchy restart shell
omarchy plugin enable bappoz.notch
```

O volume vai para o Notchi. Brilho, mídia e outros avisos do sistema mantêm um OSD separado. Se a instalação foi feita copiando arquivos e o comando disser que a pasta não é um checkout Git, remova essa cópia com `omarchy plugin remove bappoz.notch`. O Omarchy guarda instalações manuais numa pasta de backup. Em seguida, use o comando de primeira instalação. Em um checkout com alterações locais, preserve suas mudanças antes de atualizar.

Confira a versão instalada com:

```sh
jq -r .version ~/.config/omarchy/plugins/bappoz.notch/manifest.json
```

### Atalhos e voz

O dock tem um botão de microfone. Para adicionar também os atalhos globais, inclua as linhas desejadas no seu `~/.config/hypr/bindings.lua`, evite duplicatas e recarregue com `hyprctl reload`:

```lua
o.bind("SUPER + ALT + N", "Notchi", "omarchy-shell bappoz.notch toggle")
o.bind("SUPER + ALT + V", "Notchi voice", "omarchy-shell bappoz.notch.service voice")
```

A voz usa `pw-record` e [Superwhisper para Linux](https://superwhisper.com/linux). Experimente “Abra o Firefox”, “Abra o calendário”, “Volume em 40” ou “Pause a música”. O plugin usa a entrada e o modo de transcrição configurados no Superwhisper. No modo Cloud, o Superwhisper envia o áudio para processamento. O Cursor Buddy só aparece se o Hyprland identificar a janela do aplicativo.

### Remoção e dados locais

```sh
omarchy plugin remove bappoz.notch
```

O gerenciador restaura o OSD padrão se ele foi substituído pelo Notchi. Remova os atalhos que adicionou ao Hyprland e recarregue a configuração. A remoção preserva tarefas e ajustes em `~/.local/state/omarchy-notch`, fotos em `~/.local/share/omarchy-notch` e credenciais opcionais em `~/.config/omarchy-notch`. Esses dados são locais e não migram com a instalação em outro computador.

## Register AI agents and MCPs

Notchi observes existing Omarchy agent records; it does not create AI accounts or run another AI model. Install and sign in to the provider's supported client first. On current Omarchy, supported subscription accounts can be registered using:

```sh
omarchy agent account add claude
omarchy agent account add codex
omarchy agent usage update --force claude codex agy
```

Authenticate Antigravity in its own client. Availability depends on the installed native collector. Open AI → Quotas to see the source age, then click a provider for details. Claude/Codex sessions appear from local metadata; an idle/monitoring state is distinct from active coding. Missing counters remain unknown. Other clients' quotas may be visible without live session animation support.

**MCP servers are configured in Claude Code, Codex or another MCP host, not in Notchi.** This release is not an MCP client/server, does not offer desktop-control tools, and does not store MCP credentials. Follow your agent's official MCP setup documentation, then run the agent normally; Notchi can reflect its reported tool/monitoring activity. Never paste credentials into issues, screenshots or contribution requests.

## Open source and contributions

Notchi is open source under the MIT license. Anyone may use, copy, modify and redistribute it under that license, preserving the included copyright and third-party notices. It is an independent adaptation, not an official Omarchy, Apple, Anthropic or OpenAI product.

Design suggestions, feature ideas, bug reports and pull requests are welcome! Open an issue to discuss improvements or submit a PR with screenshots and verification. The maintainer will review contributions and try to accept useful, compatible improvements; acceptance is not guaranteed. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Fontes e créditos

- [OpenNotchi](https://github.com/nannndev/OpenNotchi) — base visual e de animação, geometria do contorno e logos dos provedores; licença MIT preservada.
- [ILoveNotch](https://github.com/niyamvora/ILoveNotch), de niyamvora — referência adicional para tarefas e organização do painel de consumo; implementação própria em Qt, sem código Swift ou assets copiados.
- [Lucide](https://github.com/lucide-icons/lucide) — ícones vetoriais; licenças ISC/MIT incluídas.
- [Inter](https://github.com/rsms/inter) — tipografia da versão multiplataforma; SIL OFL incluída.
- [PrayTime](https://github.com/zarrabi/praytime), de Hamid Zarrabi-Zadeh — cálculo offline; código original e licença em `vendor/`.
- [Hyprland: regras de janelas](https://wiki.hypr.land/configuring/core/rules/window-rules/) e [dispatchers](https://wiki.hypr.land/0.57.0/configuring/core/dispatchers/) — APIs de foco/regras verificadas também na instalação local 0.56.2.
- [Home Assistant REST API](https://contributors.home-assistant.io/core/internals/rest-api/), [Spotify Web API](https://developer.spotify.com/documentation/web-api/reference/get-a-users-available-devices), [Open-Meteo](https://open-meteo.com/en/docs), [Frankfurter](https://frankfurter.dev/), [CoinGecko](https://docs.coingecko.com/reference/coins-markets), [Alpha Vantage](https://www.alphavantage.co/documentation/) e [LRCLIB](https://lrclib.net/docs) — fontes dos conectores opcionais.

## Privacy fix — 0.6.1

Lyrics metadata is passed to the Python worker through a private stdin pipe, never in its command-line arguments. This prevents disclosure through concurrent process-command-line inspection by another local account. The documented LRCLIB network lookup still receives artist/title/album/duration when the Lyrics view requests a lookup; stdin transport does not make that external lookup private. No temporary metadata file or metadata environment variable is created.

## Timer privacy fix — 0.6.2

Custom timer messages travel as bounded JSON through stdin, never QML/Python command arguments. The transient user-systemd service receives only a timer identifier and the state location. `timer_notify.py` reads the existing owner-only state file under its lock and calls the session notification service directly through Gio D-Bus, without a notification CLI subprocess or message environment variable. Delivery clears the completed timer payload; cancellation/replacement invalidates older identifiers. This protects against other local accounts inspecting process command lines, not against the account owner, root, the notification service or someone viewing the screen.

Timers require the distribution Python at `/usr/bin/python3` and PyGObject/Gio (`python-gobject` on Arch). Availability is checked before scheduling so an existing timer remains unchanged if the dependency is missing. Restarting the shell does not affect delivery. As of 0.6.3, ordinary service startup/refresh automatically migrates saved legacy timers before their later execution. No software can retract command-line data that has already been observed. The separate “Reminders” shortcut delegates to Omarchy's own reminder application and is outside Notchi's timer implementation.

Regression verification: `python -m unittest discover -s tests`; private notification-bus delivery test: `dbus-run-session -- /usr/bin/python3 tests/timer_dbus_probe.py`. The probe uses synthetic text and never sends a notification to the normal desktop bus.

Delivery is one-shot: success or failure clears the stored message. Failures log a generic error, and later cancellation/replacement recovers even when systemd has already collected the previous units.

0.6.2 verification: all 94 tests passed with native Qt tests enabled; isolated real D-Bus delivery passed while checking the helper's argv/environment; real user-systemd scheduling, ExecStart inspection, cancellation and stale-unit recovery passed. An independent read-only Claude review approved the corrected implementation. This is targeted verification, not a guarantee that the entire plugin has no vulnerabilities.

## Pending legacy timers — 0.6.3

On normal startup/reload and status refresh, Notchi migrates saved timers from earlier versions, including 0.6.2. It stops the old timer and service, checkpoints the message privately, and schedules the direct-Gio helper for the remaining time using the original deadline. Already collected historical units and legacy records whose saved deadlines have passed are cleared without resurrecting a finished reminder; private pending retries can deliver late. The legacy clock deadline cannot prove whether a notification was already sent, especially across suspend, so this policy favors avoiding duplicate legacy notifications.

If dependency checks or rescheduling fail, the old argv command remains disabled and the private payload stays pending for retry on refresh. A visible migration warning is returned. Failed stop operations do not falsely mark migration complete. This covers saved Notchi timers in the same user's service manager, not arbitrary external reminder applications or data observed before migration.

0.6.3 verification: 100 non-visual tests passed (two optional UI tests skipped), real legacy user-systemd migration preserved a future deadline and removed the old command, and the isolated D-Bus probe passed. The broad native navigation test was intermittent on this host; isolated snappy/bouncy cases passed, but the complete UI suite is not claimed green for this release. Independent read-only review approved the migration after crash-recovery and malformed-state fixes.
