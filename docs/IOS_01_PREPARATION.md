# IOS-01 — preparación sin dispositivo

Fecha: 2026-10-03. Baseline inspeccionado:
`61dfce343975eca377c778651234f940733a032a`. IOS-01 sigue pendiente: su aceptación
exige compilar, instalar y abrir en iPhone 17. Esta preparación no exportó ni
compiló una build iOS y no sustituye la validación de M3 integrado.

## Evidencia del entorno

| Elemento | Resultado observado |
|---|---|
| macOS | 27.0.1, build 26A434 |
| Godot | 4.7.2.stable.official.ed1daf0bf |
| Xcode | 27.0, build 27A266a |
| `xcode-select -p` | `/Applications/Xcode.app/Contents/Developer` |
| `xcrun --sdk iphoneos --show-sdk-version` | 27.0, exit 0 |
| Export templates | `~/Library/Application Support/Godot/export_templates` existe y está vacío |
| Preset | No existe `export_presets.cfg` en el baseline |
| Firma | `security find-identity -v -p codesigning`: 0 identidades válidas, exit 0 |
| Provisioning | 0 perfiles en las rutas estándar de MobileDevice y Xcode; ambas carpetas ausentes |
| Dispositivos | `xcrun devicectl list devices --timeout 20`: exit 0, **0 dispositivos** |

Firma y enumeración se verificaron fuera del sandbox: la primera enumeración
restringida falló y no se interpretó como ausencia de hardware. Solo se retuvieron
conteos; no se guardaron certificados, perfiles, nombres ni identificadores de
dispositivos. No se instalaron herramientas/templates ni se cambiaron cuentas.
Evidencia local: `/private/tmp/m3-audit-baseline/ios-environment.json` e
`ios-signing-device-counts.json`.

## Configuración de proyecto y bloqueantes

El baseline apunta a `res://scenes/Main.tscn`; viewport 1080×1920, orientación
portrait (`1`), stretch `canvas_items`/`expand`, renderer `mobile`. La escena
principal debe revisarse de nuevo tras integrar App/RST-01; no se exportará un
SHA que todavía arranque el wiring anterior por accidente.

Los bloqueantes actuales de exportación son templates iOS de la versión exacta
y un preset real. Bundle ID y Team ID todavía no están configurados. Godot exige
ambos para exportar a Xcode; deben proceder del equipo, sin inventar identidades.
Fuente: [exportación iOS de Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

El futuro preset debe incluir los **7 JSON** de `data/content/*.json`: ingredientes,
recetas, monstruos, jefe, oleadas, mejoras y localización. ContentRegistry los abre
mediante FileAccess; comprobar su presencia y carga en el paquete exportado. El
filtro de archivos no-resource permite incluir JSON. El preset se versiona;
`.godot/export_credentials.cfg` permanece local y excluido por `.godot/`.
Fuente: [configuración y exportación de proyectos Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html).

No existe aún proyecto Xcode para comprobar deployment target, arquitectura,
orientaciones del target o capacidades de firma. Al generarlo, verificar arm64,
portrait y un deployment target compatible con ambos dispositivos reales. La
versión de iOS del iPhone 16 Pro Max sigue pendiente de registro; no inferirla.

## Secuencia reproducible pendiente

1. Integrar y validar M3/RST-01; registrar SHA y escena de arranque. Reejecutar la
   [regresión](M3_BASELINE_VALIDATION.md) sobre ese SHA.
2. Instalar solo los templates iOS correspondientes a Godot 4.7.2 mediante el
   administrador de templates. Crear el preset `iOS` con Bundle ID/Team ID reales
   y filtro `data/content/*.json`; revisar sus opciones antes de versionarlo.
3. Exportar a una carpeta vacía fuera del repositorio. La CLI de Godot documenta
   `.zip` para iOS; el proyecto Xcode resultante debe inspeccionarse antes de compilar:

   ```sh
   mkdir -p /private/tmp/lut-ios-export
   godot --headless --path . --export-debug "iOS" /private/tmp/lut-ios-export/LaUltimaTaqueria.zip
   ```

4. Abrir el proyecto exportado o listar sus schemes. En los comandos siguientes,
   definir `LUT_XCODE_PROJECT` y `LUT_SCHEME` con los valores realmente generados:

   ```sh
   xcodebuild -list -project "$LUT_XCODE_PROJECT"
   xcodebuild -showBuildSettings -project "$LUT_XCODE_PROJECT" -scheme "$LUT_SCHEME"
   xcodebuild -project "$LUT_XCODE_PROJECT" -scheme "$LUT_SCHEME" -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/lut-ios-derived CODE_SIGNING_ALLOWED=NO build
   ```

   Esta compilación sin firma permite separar errores de proyecto de los de
   signing; no crea una app instalable en iPhone. Revisar settings y log efectivos.
5. Configurar firma de desarrollo válida en Xcode, conectar/emparejar el iPhone 17
   y habilitar su Developer Mode. Compilar para ese dispositivo con firma. Con
   `LUT_DEVICE_ID`, `LUT_APP_PATH` y `LUT_BUNDLE_ID` reales, la CLI instalada admite:

   ```sh
   xcrun devicectl list devices --timeout 20
   xcrun devicectl device install app --device "$LUT_DEVICE_ID" "$LUT_APP_PATH"
   xcrun devicectl device process launch --device "$LUT_DEVICE_ID" --console "$LUT_BUNDLE_ID"
   ```

6. Registrar build/commit, dispositivo/iOS, arranque, recursos de contenido, una
   partida completa, victoria/derrota y restart. Solo entonces evaluar cierre de
   IOS-01; IOS-02 mide rendimiento y temperatura, INP-01 valida input, y VAL-01/02
   conservan sus propias aceptaciones. No borrar ni resetear metapersistencia.

## INP-01: evidencia y contadores

El probe local confirmó `emulate_mouse_from_touch=true` y
`emulate_touch_from_mouse=false`, tanto en ProjectSettings como en Input runtime.
BoardView procesa ScreenTouch/ScreenDrag y MouseButton/MouseMotion sin dedupe;
`begin_chain_at()` emite `chain_started` cada vez que se acepta un inicio.

`tests/board_input_test.gd` (398 checks) y `tests/upg_02h_steady_hands_test.gd`
(1263) ya conectan contadores a `chain_started`/`chain_completed` y despachan input
real de SubViewport. Cubren mouse y touch por separado. Un harness temporal
adicional inyectó explícitamente ambos eventos para el mismo gesto y observó
**2 inicios / 1 finalización**. Es un par sintético forzado: demuestra sensibilidad
del contador, no que iOS entregue ambos eventos ni que el bug ocurra en hardware.
Harness/log locales: `project/probe_paired_input.gd` y `paired-input.log` bajo
`/private/tmp/m3-audit-baseline`; no forman parte del producto.

En build de diagnóstico física, conectar una vez esos dos contadores a la sesión
vigente y registrar tipo de evento, device, índice touch y timestamp de recepción.
Comparar un tap, cadena válida, cadena cancelada y gesto tras restart con y sin
steady_hands: un inicio por gesto aceptado, una finalización por cadena válida,
cero finalizaciones en cancelación. Verificar que restart no deja listeners viejos.
Solo con esa evidencia decidir explícitamente desactivar emulación o deduplicar;
no se cambia el contrato D8 ni se implementa una solución preventiva aquí.
