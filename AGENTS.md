# AGENTS.md

Este arquivo orienta assistentes de IA (Claude Code, Codex, Cursor, Gemini CLI e
afins) ao trabalhar com o código deste repositório.

## O que é isto

O Vitro é um editor de notas para macOS: texto rico com checkboxes interativos,
persistido como JSON (Markdown apenas em Export explícito). As notas abrem como
**abas de janela nativas do macOS**.

**Requer macOS 26 (Tahoe) e Swift 6.** O deployment target e o comportamento de
Liquid Glass / abas nativas dependem do SDK do Tahoe — ele não compila para macOS
anteriores.

## Compilar / executar

- `swift build` — checagem rápida de compilação (SPM). Use para pegar erros rápido.
- `sh scripts/run-local.sh` — o fluxo real: compila em **Release** via `xcodebuild`,
  substitui `/Applications/Vitro.app` e o abre. Use para ver as mudanças no app de
  verdade (assinado ad-hoc, sem notarização).
- **`xcodegen generate` depois de adicionar, remover ou renomear qualquer arquivo-fonte.**
  O projeto Xcode é gerado a partir do `project.yml` e sua lista de arquivos fica
  desatualizada — o `swift build` passa, mas o `xcodebuild` (e portanto o
  `run-local.sh`) falha com "cannot find X in scope". Não há testes.

## Arquitetura

Este é um **app em AppKit puro** (não é ciclo de vida SwiftUI). O ponto de entrada é
código de topo em `main.swift`, que cria o `AppController` (NSApplicationDelegate). O
motivo do AppKit puro é o controle de janelas: cada nota é sua própria subclasse de
`NSWindow`, para podermos conduzir o tabbing nativo e o estilo da barra de título que o
SwiftUI não expõe.

**Camada de janela/abas** (`Sources/Vitro/Window/`):
- `NoteWindow` — subclasse de `NSWindow`, uma por nota. Tabbing nativo de janela via um
  `tabbingIdentifier` compartilhado (`.preferred` → `.automatic`); as abas aparecem na
  posição padrão do sistema, abaixo de uma barra de título transparente de conteúdo
  full-size (o estilo "native" de titlebar do Ghostty — o texto do título fica oculto,
  já que as abas carregam os títulos). O botão "+" nativo funciona porque ele sobrescreve
  `newWindowForTab(_:)`.
- `NoteWindowController` — dono de um `NoteWindow` + uma `Note`, hospeda o editor via
  `NSHostingView(EditorContent)` e mantém `window.title` / `window.tab.attributedTitle`
  em sincronia com o título derivado da nota (e esmaece as abas inativas em key/resign).
- `TabController` — cria e agrupa janelas (`addTabbedWindow`), cuida de nova/fechar e
  persiste o conjunto de abas abertas. Pertence ao `AppController`; é alcançado a partir
  do `NoteWindow` via `NSApp.delegate as? AppController`.
- `AppKitSupport` — helpers de hierarquia de views (`firstDescendant(withClassName:)`,
  `titlebarView`, etc.) para alcançar views privadas do AppKit pelo nome da classe.

**Editor** (`Sources/Vitro/Editor/`): `RichTextEditor` envolve um `NSTextView` customizado
(`CheckboxTextView`). Trocar de aba recria a view inteira (`.id(note.id)` mais acima), então
`makeNSView` carrega do zero e `updateNSView` é no-op. Comandos do editor (inserir
checklist, tamanho da fonte) são entregues como broadcasts de `NotificationCenter`
(`.vitroInsertCheckbox`, `.vitroAdjustFont`) que o `CheckboxTextView` observa — as ações
de menu do `AppController` os publicam. `Checkbox` também define o enum de export
`Markdown`. `LineNumberRulerView` é a régua (gutter).

**Models** (`Sources/Vitro/Models/`): `Note` é um `ObservableObject`; seu `title` é
*derivado* da primeira linha não vazia do corpo (estilo Apple Notes) — não há título
armazenado. `NotesStore` é dono de todas as notas e as salva com debounce como `notes.json`
em Application Support. O export para um arquivo `.md` é separado e opt-in.

## Convenções / armadilhas

- **Uma única tipografia: Inter.** Use `Note.interFont(ofSize:weight:)` para qualquer fonte
  (volta para a fonte do sistema se a Inter não estiver instalada). Não fixe
  `NSFont.systemFont` no código.
- **Liquid Glass:** o glass é o chrome nativo desenhado pelo SO (abas/barra de título no
  Tahoe) mais o `VisualEffectBackground` (blur `.behindWindow`) atrás do conteúdo do editor.
  Segundo a orientação da Apple, **não** coloque glass atrás do próprio texto do editor —
  glass é para a camada de controle/navegação, não para o conteúdo.
- **Chaves de persistência** (`UserDefaults`): `openTabs` / `selectedTab` (abas abertas) e
  `editorFontSize`. Os corpos das notas vivem no `notes.json`, não no UserDefaults.
- **Legado/não usado** do design anterior às abas nativas, mantido só para evitar uma
  exclusão não solicitada: `Views/RootView.swift`, `Models/Workspace.swift` e o representable
  `WindowConfigurator` em `Window/WindowConfigurator.swift` (o `VisualEffectBackground` dele
  *ainda* é usado). Seguro de remover.
