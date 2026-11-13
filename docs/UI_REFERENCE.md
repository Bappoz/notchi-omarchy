# Base visual do OpenNotchi

Referência: [nannndev/OpenNotchi](https://github.com/nannndev/OpenNotchi), revisão `817e2e0b3464e8df01cace0acdc354de24c9f403`, consultada em 7 de novembro de 2026. Licença MIT preservada. Esta adaptação é independente.

As capturas oficiais em `apps/website/public/preview/` foram comparadas com capturas da implementação rodando em Wayland. A versão 0.2 substitui o layout inicial por componentes baseados no código original.

| Referência no repositório original | Adaptação local |
| --- | --- |
| `apps/macos/Sources/OpenNotchi/Notch/NotchShape.swift` | `plugin/NotchShape.qml`: orelhas, curvas inferiores e contorno aberto na borda superior |
| `Notch/NotchViewModel.swift`, `Views/Notch/NotchLayout.swift` | Conteúdo de 680 px (720 px em IA), orelhas de 14 px, altura inicial de 200 px, colunas laterais de 124 px e espaçamento de 18 px |
| `Views/HeaderView.swift` | `plugin/ui/Header.qml`: ícones pequenos, nome da seção selecionada, marcador que acompanha a seleção, relógio/bateria/menu |
| `Views/Home/PlayerView.swift`, `PlayerControls.swift` | `plugin/Home.qml`: título/artista centralizados, progresso fino com tempos nas extremidades, botão circular de 32 px e volume de 64 px |
| `Views/Home/TurntableViews.swift` | `plugin/ui/Vinyl.qml`: disco de 112 px com sulcos, selo central, agulha animada e rotação de 45 graus por segundo |
| `Views/CalendarWidget.swift` | `plugin/ui/DeskCalendar.qml`: calendário lateral de 112 × 112 px |
| Capturas `home.webp`, `ai.webp`, `closed-music.webp` | Player, disposição dos cartões de cotas e ilha fechada com arte e waveform |
| `Settings/NotchAnimationStyle.swift`, `apps/windows/src/styles.css` | `plugin/ui/Motion.js`, `CardTransform.js` e `Notch.qml`: nove perfis, curvas Bézier, escala/deslocamento/blur e rotação em perspectiva |

Os seis perfis 2D usam as curvas e durações da implementação Windows. Os três perfis 3D usam os ângulos e escalas do modificador Swift, com matriz em perspectiva equivalente em Qt. O vinil e o waveform atualizam a cada quadro enquanto visíveis e reproduzindo. Todas as transições respeitam a preferência de animações.

## Ícones, logos e tipografia

- Os PNGs `claude`, `codex`, `antigravity` e `commandcode` foram copiados de `apps/macos/Sources/OpenNotchi/Resources/ProviderIcons/` nessa revisão.
- A versão Windows usa `lucide-react`. Esta adaptação inclui SVGs oficiais do [Lucide](https://github.com/lucide-icons/lucide), revisão `53fab88ff9d1b48f4704b5b5b560d6b4d560bf4c`, com traço branco. As licenças ISC e Feather MIT ficam em `plugin/assets/icons/LICENSE`. Aliases locais preservam nomes anteriores da biblioteca.
- Os controles preenchidos de reprodução e a legenda são geometrias SVG simples reconstruídas para manter o peso visual do player. Os SF Symbols do macOS são fornecidos pelo sistema Apple, não arquivos redistribuídos pelo projeto; não foram extraídos.
- A versão multiplataforma usa Inter. `plugin/assets/fonts/InterVariable.ttf` vem do [projeto oficial Inter](https://github.com/rsms/inter), com licença SIL Open Font License em `LICENSE.txt`. Não depende das fontes instaladas no computador.

## Organização e diferenças da plataforma

`plugin/ui/` concentra os componentes visuais compartilhados; cada página contém sua composição. Os adaptadores locais e os acessos aos painéis nativos continuam no serviço/backend. Não foram introduzidas consultas de rede para baixar ícones ou fontes em tempo de execução.

O layout e as animações foram portados, mas Qt/Hyprland e SwiftUI não rasterizam de forma idêntica. O vidro usa blur do compositor, transparência e contorno; a refração nativa do macOS não está disponível. Os vetores Lucide substituem os símbolos nativos Apple conforme a biblioteca já usada pelo próprio OpenNotchi no Windows. As outras diferenças funcionais estão no README.
