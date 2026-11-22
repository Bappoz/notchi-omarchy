# Base visual do OpenNotchi

Referência: [nannndev/OpenNotchi](https://github.com/nannndev/OpenNotchi), revisão `817e2e0b3464e8df01cace0acdc354de24c9f403`, consultada em 7 de novembro de 2026. Licença MIT preservada. Esta adaptação é independente.

As capturas oficiais em `apps/website/public/preview/` foram comparadas com capturas da implementação rodando em Wayland. A composição atual usa uma cápsula central em Wayland, com navegação pelo dock inferior e componentes próprios de HUD.

| Referência no repositório original | Adaptação local |
| --- | --- |
| `apps/macos/Sources/OpenNotchi/Notch/NotchShape.swift` | `NotchShape.qml`: orelhas, curvas inferiores e contorno aberto na borda superior |
| `Notch/NotchViewModel.swift`, `Views/Notch/NotchLayout.swift` | `Notch.qml`: áreas de expansão com largura ajustada à tela e contorno compartilhado entre as páginas |
| `Views/HeaderView.swift` | `ui/Header.qml` para nome, hora, bateria e ajustes. `ui/NavigationDock.qml` para ícones e seleção deslizante |
| `Views/Home/PlayerView.swift`, `PlayerControls.swift` | `Home.qml`: título/artista centralizados, progresso fino com tempos nas extremidades, botão circular de 32 px e volume de 64 px |
| `Views/Home/TurntableViews.swift` | `ui/Vinyl.qml`: disco de 112 px com sulcos, selo central, agulha animada e rotação de 45 graus por segundo |
| `Views/CalendarWidget.swift` | `ui/MiniCalendar.qml` e `Calendar.qml`: mês com marca no dia atual e página completa |
| Capturas `home.webp`, `ai.webp`, `closed-music.webp` | Player, disposição dos cartões de cotas e ilha fechada com arte e waveform |
| `Settings/NotchAnimationStyle.swift`, `apps/windows/src/styles.css` | `ui/Motion.js`, `CardTransform.js` e `Notch.qml`: nove perfis, curvas Bézier, escala/deslocamento/blur e rotação em perspectiva |

Os seis perfis 2D usam as curvas e durações da implementação Windows. Os três perfis 3D usam os ângulos e escalas do modificador Swift, com matriz em perspectiva equivalente em Qt. O vinil e o waveform atualizam a cada quadro enquanto visíveis e reproduzindo. Todas as transições respeitam a preferência de animações.

## Ícones, logos e tipografia

- Os PNGs `claude`, `codex`, `antigravity` e `commandcode` foram copiados de `apps/macos/Sources/OpenNotchi/Resources/ProviderIcons/` nessa revisão.
- A versão Windows usa `lucide-react`. Esta adaptação inclui SVGs oficiais do [Lucide](https://github.com/lucide-icons/lucide), revisão `53fab88ff9d1b48f4704b5b5b560d6b4d560bf4c`, com traço branco. As licenças ISC e Feather MIT ficam em `assets/icons/LICENSE`. Aliases locais preservam nomes anteriores da biblioteca.
- Os controles de reprodução e a legenda usam geometrias próprias. Os ícones `emblem-*.svg` foram desenhados para o dock, calendário e Bluetooth com traço claro e detalhe em cor. Os SF Symbols do macOS são fornecidos pelo sistema Apple, não arquivos redistribuídos pelo projeto; não foram extraídos.
- A versão multiplataforma usa Inter. `assets/fonts/InterVariable.ttf` vem do [projeto oficial Inter](https://github.com/rsms/inter), com licença SIL Open Font License em `LICENSE.txt`. Não depende das fontes instaladas no computador.

## Organização e diferenças da plataforma

`ui/` concentra os componentes visuais compartilhados; cada página contém sua composição. Os adaptadores locais e os acessos aos painéis nativos continuam no serviço/backend. Não foram introduzidas consultas de rede para baixar ícones ou fontes em tempo de execução.

O layout e as animações foram portados, mas Qt/Hyprland e SwiftUI não rasterizam de forma idêntica. O vidro usa blur do compositor, transparência e contorno; a refração nativa do macOS não está disponível. Os símbolos do dock usam desenho próprio. Outros controles reutilizam Lucide conforme a biblioteca já usada pelo OpenNotchi no Windows. As outras diferenças funcionais estão no README.
