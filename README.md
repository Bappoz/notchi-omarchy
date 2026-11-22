# Notchi for Omarchy

Ilha dinâmica nativa para o shell do Omarchy, inspirada em [OpenNotchi, de nannndev](https://github.com/nannndev/OpenNotchi). Adaptação independente para Linux/Wayland, em QML/Quickshell, sob licença MIT. A superfície flutuante usa geometria e transições próprias em QML. As telas detalhadas mantêm a linhagem do OpenNotchi. Logos de provedores vêm do repositório; os vetores Lucide vêm da mesma biblioteca da versão Windows. Os créditos e as licenças estão preservados. Third-party sources and licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

![Notchi com os controles de mídia abertos](screenshots/island-media.png)

## Usar

- Passe o mouse sobre a cápsula no topo para abrir os controles rápidos. Um clique ou **Super + Alt + N** abre no monitor em foco e fixa a ilha. **Esc** fecha.
- A roda do mouse sobre a cápsula ajusta o volume. Quando a barra fica no topo, a cápsula ocupa o centro junto à borda, com 8 px de respiro.
- O menu **…** leva às telas completas e aos ajustes. As telas detalhadas têm navegação própria e **Ctrl + 1 … 8** mantém os atalhos das seções.
- Ative **Ajustes → Aparência → Alertas do desktop** para chamadas, notificações e transferências. Para exemplos sem contas reais e a matriz de validação, veja [Ilha flutuante](docs/FLOATING_ISLAND.md).

## O que está incluído

| Área | Disponível nesta versão |
| --- | --- |
| Aparência | Cápsula centralizada, três aparências e nove perfis de abertura (seis 2D e três 3D). Respeita as animações desligadas no Omarchy |
| Monitores | Uma ilha em cada tela; atalho abre no monitor em foco |
| Mídia | Fontes MPRIS, capa, vinil giratório, reproduzir/pausar, anterior/próxima, seek, shuffle/repeat quando o player expõe esses controles; volume e mute |
| Vídeo | Prévia ao vivo de uma janela escolhida; algumas janelas minimizadas não fornecem imagens ao compositor |
| Letras | Abrir Letras inicia a consulta ao LRCLIB; envia artista, título, álbum e duração. Trocas de faixa atualizam a letra somente enquanto a tela está aberta. Aceita letras sem sincronia e arquivos LRC |
| Agenda | Calendário, relógios de São Paulo/Londres/Dubai/Tóquio/Los Angeles, acesso ao calendário completo e ao globo originais |
| Reuniões | Acesso ao plugin existente de próximos eventos; o feed e sua configuração são preservados |
| Foco | Cronômetro na sessão do shell, timer com presets, duração e mensagem personalizadas; alerta entregue pelo systemd mesmo com o painel fechado ou recarregado |
| Arquivos | Soltar arquivos ou escolher pela janela de seleção; abrir, revelar, arrastar para fora, remover referência, OCR e conversão PNG/JPEG/WebP |
| Clipboard | Histórico já existente do Omarchy, busca e cópia de texto/imagens; sem instalar outro capturador de clipboard |
| Câmera | Prévia iniciada por botão, 18 estilos e quatro opções de moldura com seletores circulares e prévia ao vivo, fotos e desenho livre; originais preservados. Fecha o painel para desligar |
| Agentes | Cartões clicáveis com tokens de hoje, histórico diário e modelos quando reportados; cotas de uso consumido, atualizadas pelos coletores nativos a cada cinco minutos, horário/estado da leitura e atualização manual. Sessões Claude/Codex com atividade, projeto, workspace identificado, tokens e contexto quando reportados |
| Sistema | Aba ao lado de IA, com CPU, memória, disco, tráfego de rede com histórico e bateria do notebook |
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

Esta é a versão **0.6.0**. A interface foi reconstruída a partir da referência; as APIs específicas de cada sistema continuam tendo as diferenças abaixo.

- O compartilhamento prepara o arquivo no **LocalSend** já instalado, onde você escolhe o destinatário. Não implementa o protocolo Apple AirDrop. A referência antiga a OmDrop na configuração deste computador não corresponde a um plugin instalado.
- Não há haptics de hardware, gestos de mão por visão computacional, segmentação de retrato ou leitura proprietária de bateria esquerda/direita/estojo de AirPods. Baterias expostas pelo Linux aparecem no painel.
- Os nove perfis foram adaptados para Qt, incluindo transformação em perspectiva, blur e escurecimento nos três efeitos 3D. A refração nativa de Liquid Glass do macOS não está disponível no Hyprland; vidro usa transparência, contorno e blur do compositor.
- Letras usam timestamps, foco/rolagem por linha e blur nas linhas distantes; o alinhamento depende dos dados LRC recebidos.
- Os estilos têm prévia em GPU e exportação não destrutiva. O processamento da foto em resolução completa pode produzir pequenas diferenças em relação à prévia. O editor oferece três decorações e desenho, sem todo o catálogo de adesivos do projeto original.
- Favoritar faixas e controle remoto completo do Spotify ficam no cliente original; o conector desta versão transfere reprodução entre dispositivos. Tokens inseridos manualmente precisam ser renovados quando expirarem.
- OCR de PDF usa **a primeira página**. Para documentos maiores, use o aplicativo de OCR/PDF de sua preferência.
- Os relógios usam um conjunto inicial de cidades. A edição visual das cidades continua disponível no globo original.
- Updates are distributed through this Git repository and the Omarchy plugin manager.

Os conectores autenticados foram validados com testes isolados, **sem conexão à conta/dispositivos do usuário**, pois nenhuma credencial foi fornecida. A câmera foi carregada com captura desligada; a captura real depende do dispositivo e de sua permissão.

## Conectar serviços opcionais

Abra **Ajustes → Conectar integrações**. Preencha somente os serviços que deseja usar. Os campos de chave vazios preservam chaves já salvas; nenhuma chave salva é devolvida à interface. Elas ficam em um arquivo privado deste computador, com permissão de leitura/escrita apenas para seu usuário.

Em **Controles → Clima, mercados, casa e Spotify Connect**, escolha o serviço e clique **Atualizar**. As consultas extras não rodam em segundo plano. Oração é calculada offline. A opção de avisos programa somente os horários restantes **do dia atual**.

O token Home Assistant é um long-lived access token do seu perfil. Para Spotify Connect, o token precisa de `user-read-playback-state` e `user-modify-playback-state`; a disponibilidade também depende das regras do Spotify. Este plugin não implementa login OAuth nem renovação automática.

## Install, update and remove

Requires the current Omarchy Quickshell shell, Python 3 and Hyprland (Lua configuration). This is not a Waybar plugin.

```sh
omarchy plugin add https://github.com/Bappoz/notchi-omarchy --enable
```

Add `bappoz.notch` to your bar using Omarchy's bar settings. Installing the plugin does not replace your bar layout, change window rules, or install a keyboard binding. The original AI panel can remain enabled alongside Notchi. Use the Omarchy plugin manager to update it.

```sh
omarchy plugin remove bappoz.notch
```

Removing the plugin does not delete your task list or photos. Settings/tasks live under `~/.local/state/omarchy-notch`, optional integration credentials under `~/.config/omarchy-notch`, and photos under `~/.local/share/omarchy-notch`. Back up these folders before deleting them manually.

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
- [PrayTime](https://github.com/zarrabi/praytime), de Hamid Zarrabi-Zadeh — cálculo offline; código original e licença em `plugin/vendor/`.
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
