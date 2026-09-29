# Auditoría de colores hardcodeados en `lib/`

*Búsqueda exhaustiva de 13 patrones de color en todos los archivos `.dart` de `lib/`. Sin cambios de código — solo reporte.*

## Metodología para el patrón #11 (`Colors.white`)

El patrón se buscó como símbolo exacto (`Colors.white`), **no** sus variantes (`Colors.white70`, `Colors.white54`, `Colors.white38`, `Colors.white24`, `Colors.white12`) — esas se listan aparte, al final, para no perderlas de vista, pero no cuentan como coincidencias del patrón #11 tal como se pidió.

Para cada aparición de `Colors.white` exacto se determinó el contexto leyendo el widget que lo envuelve (no solo la línea aislada):
- **Se incluye** si tiñe texto (`TextStyle`, `labelStyle`, `hintStyle`), un ícono (`Icon(...)`, `IconThemeData`), el texto/ícono de un botón (`foregroundColor` en botones), o un color semántico "sobre" (`onPrimary`, `onSecondary`, `onError` en un `ColorScheme`).
- **Se excluye** si pinta un fondo, borde, sombra, divisor, línea decorativa o efecto de toque (`BoxDecoration`/`Container` de fondo, `Border.all`, `BorderSide`, `shadowColor`, `highlightColor`, `Divider`, barras de arrastre ("handle"), puntos/gráficos de estado).

No existe ningún patrón con match exacto para: `Color(0xFF333333)`, `AppTheme.darkTextPrimary`, `AppTheme.darkBorder`, `Color(0xFF1C1C1C)`, `Color(0xFF252525)` — **ninguno de estos 5 aparece en el código**; los nombres reales de las constantes son `AppTheme.darkText` (no `darkTextPrimary`) y no existe ningún `darkBorder` en `AppTheme`.

## Resumen por patrón

| # | Patrón | Coincidencias | Archivos |
|---|---|---|---|
| 1 | `Color(0xFF1A1A1A)` | 10 | 9 |
| 2 | `Color(0xFF2A2A2A)` | 2 | 2 |
| 3 | `Color(0xFF333333)` | 0 | 0 |
| 4 | `Color(0xFF121212)` | 5 | 2 |
| 5 | `AppTheme.darkBackground` | 32 | 24 |
| 6 | `AppTheme.darkSurface` | 95 | 45 |
| 7 | `AppTheme.darkTextPrimary` | 0 | 0 |
| 8 | `AppTheme.darkTextSecondary` | 141 | 52 |
| 9 | `AppTheme.darkBorder` | 0 | 0 |
| 10 | `Colors.black` (todas, incl. `.black54`) | 60 | 30 |
| 11 | `Colors.white` (exacto, solo texto/ícono) | ~78 de 130 brutas | ~45 |
| 12 | `Color(0xFF1C1C1C)` | 0 | 0 |
| 13 | `Color(0xFF252525)` | 0 | 0 |

---

## Resultados por archivo

### `lib/main.dart`
- L128 `#10` `      systemNavigationBarColor: isDark ? Colors.black : Colors.white,` *(ambos: fondo de barra de navegación del sistema — excluido de #11 por ser fondo, incluido en #10 tal cual)*

### `lib/core/theme/app_theme.dart`
- L11 `#6*` `  static const Color darkSurface = Color(0xFF1A1A1A);` *(definición de la propia constante — la constante `#6` referenciada en otros archivos apunta aquí)*
- L29 `#1` `  static const Color lightTextPrimary = Color(0xFF1A1A1A);` *(en el bloque de tema claro — mismo valor hex, no relacionado con `darkSurface`)*
- L44 `#11` `        onPrimary: Colors.white,`
- L45 `#10` `        onSecondary: Colors.black,`
- L48 `#11` `        onError: Colors.white,`
- L63 `#11` `          foregroundColor: Colors.white,`
- L147 `#10` `        onPrimary: Colors.black,`
- L148 `#10` `        onSecondary: Colors.black,`
- L151 `#11` `        onError: Colors.white,`
- L166 `#10` `          foregroundColor: Colors.black,`

### `lib/core/utils/custom_map_markers.dart`
- L54 `#4` `      ..color = const Color(0xFF121212)`
- L67 `#11` `          color: Colors.white,` *(texto letra "A" del marcador)*
- L103 `#4` `      ..color = const Color(0xFF121212)`
- L116 `#11` `          color: Colors.white,` *(texto letra "B")*
- L217 `#11` `            color: Colors.white.withValues(alpha: 0.92),` *(línea 1 badge de ruta)*
- L232 `#11` `            color: Colors.white,` *(línea 2 badge de ruta)*
- L302 `#11` `            color: Colors.white,` *(etiqueta de calle)*
- L390 `#4` `      ..color = const Color(0xFF121212)`
- L403 `#11` `          color: Colors.white,` *(letra del pin)*
- L447 excluido de #11 — `..color = Colors.white.withValues(alpha: 0.95)` (anillo del punto "mi ubicación", relleno gráfico, no texto)
- L455 excluido de #11 — `..color = Colors.white.withValues(alpha: 0.35)` (círculo interior, relleno gráfico)
- L494 `#4` `      ..color = const Color(0xFF121212)`
- L559 `#11` `          color: Colors.white.withValues(alpha: 0.92),` *(badge distancia línea 1)*
- L574 `#11` `          color: Colors.white,` *(badge distancia línea 2)*

### `lib/core/utils/marker_helper.dart`
- L84 excluido de #11 — `..color = Colors.white.withValues(alpha: 0.85)` (borde del marcador de conductor)

### `lib/presentation/cubit` — sin coincidencias en ningún archivo de esta carpeta.

### `lib/presentation/widgets/driver/driver_negotiating_card.dart`
- L33 `#1` `  static const Color _cardBg = Color(0xFF1A1A1A);`
- L71 `#10` `              color: Colors.black54,`
- L145 excluido de #11 — `const Divider(height: 1, color: Colors.white12)` (variante, y es un divisor)
- L181 `#8` `            color: AppTheme.darkTextSecondary,`
- L285 `#10` `                color: Colors.black54,`
- L473 `#11` `              color: Colors.white.withValues(alpha: 0.95),` *(ícono chip de pago)*
- L479 `#11` `                color: Colors.white,` *(texto chip de pago)*
- L502 `#10` `              foregroundColor: Colors.black,`
- L620 `#6` `          backgroundColor: AppTheme.darkSurface,`
- L634 `#8` `              hintStyle: TextStyle(color: AppTheme.darkTextSecondary),`
- L662 `#10` `                foregroundColor: Colors.black,`

### `lib/presentation/widgets/driver/driver_menu_bottom_sheet.dart`
- L16 `#6` `        color: AppTheme.darkSurface,`
- L42 excluido de #11 — `color: AppTheme.darkTextSecondary.withOpacity(0.9)` *(nota: es `#8`, no `#11`; ver línea siguiente para el `#10`)*
- L197 `#8` `        color: AppTheme.darkTextSecondary,`
- L208 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L215 `#8` `          style: TextStyle(color: AppTheme.darkTextSecondary),`
- L229 `#11` `              foregroundColor: Colors.white,`

### `lib/presentation/widgets/driver/driver_drawer.dart`
- L27 `#1` `  static const Color _headerBg = Color(0xFF1A1A1A);`
- L42 `#6` `          backgroundColor: AppTheme.darkSurface,`
- L49 `#8` `            style: TextStyle(color: AppTheme.darkTextSecondary),`
- L63 `#11` `                foregroundColor: Colors.white,`
- L133 `#6` `                                  backgroundColor: AppTheme.darkSurface,`
- L137 `#8` `                                    color: AppTheme.darkTextSecondary,`
- L146 `#11` `                                  color: Colors.white,`
- L176 `#8` `                                      color: AppTheme.darkTextSecondary,`
- L236 `#11` `                            color: Colors.white,`
- L243 `#8` `                          color: AppTheme.darkTextSecondary,`
- L296 `#11` `          color: Colors.white,`
- L303 `#8` `        color: AppTheme.darkTextSecondary,`
- L325 `#11` `              color: Colors.white,`
- L333 `#8` `              color: AppTheme.darkTextSecondary,`
- L339 `#8` `            color: AppTheme.darkTextSecondary,`
- L365 `#11` `          color: Colors.white,`
- L372 `#8` `        color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/driver/document_picker_widget.dart`
- L41 `#6` `      backgroundColor: AppTheme.darkSurface,`
- L148 `#8` `                    color: AppTheme.darkTextSecondary,`
- L171 `#8` `              color: AppTheme.darkTextSecondary,`
- L210 `#8` `                            color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/common/signed_remote_image.dart`
- L71 `#8` `              color: AppTheme.darkTextSecondary,`
- L84 `#8` `              color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/client_dashboard_main_stack.dart`
- L97 `#1` `                    color: const Color(0xFF1A1A1A),`
- L99 `#10` `                    shadowColor: Colors.black54,` *(borde/sombra, no aplica a #11)*
- L127 `#1` `                    color: const Color(0xFF1A1A1A),`
- L129 `#10` `                    shadowColor: Colors.black54,`

### `lib/presentation/widgets/client/client_drawer.dart`
- L25 `#1` `  static const Color _headerBg = Color(0xFF1A1A1A);`
- L40 `#6` `          backgroundColor: AppTheme.darkSurface,`
- L47 `#8` `            style: TextStyle(color: AppTheme.darkTextSecondary),`
- L61 `#11` `                foregroundColor: Colors.white,`
- L120 `#6` `                                  backgroundColor: AppTheme.darkSurface,`
- L124 `#8` `                                    color: AppTheme.darkTextSecondary,`
- L136 `#11` `                                        color: Colors.white,`
- L165 `#8` `                                            color: AppTheme.darkTextSecondary,`
- L198 `#11` `                            color: Colors.white,`
- L206 `#8` `                            color: AppTheme.darkTextSecondary,`
- L212 `#8` `                          color: AppTheme.darkTextSecondary,`
- L403 `#8` `                            color: AppTheme.darkTextSecondary,`
- L409 `#8` `                          color: AppTheme.darkTextSecondary,`
- L461 `#11` `          color: Colors.white,`
- L468 `#8` `        color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/client_menu_actions.dart`
- L18 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L34 `#8` `            color: AppTheme.darkTextSecondary,`
- L43 `#8` `              style: TextStyle(color: AppTheme.darkTextSecondary),`
- L93 `#6` `          backgroundColor: AppTheme.darkSurface,`
- L100 `#8` `            style: TextStyle(color: AppTheme.darkTextSecondary),`
- L136 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L167 `#11` `                  foregroundColor: Colors.white,`
- L234 `#8` `              style: TextStyle(color: AppTheme.darkTextSecondary),`

### `lib/presentation/widgets/client/client_payment_method_ui.dart`
- L70 `#6` `        color: AppTheme.darkSurface,`
- L95 `#11` `                      color: Colors.white,`
- L181 `#8` `          color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/client_menu_fab.dart`
- L17 `#6` `      backgroundColor: AppTheme.darkSurface,`

### `lib/presentation/widgets/client/client_ride_active_view.dart` *(archivo sin uso — ver `PROJECT_REPORT.md` §6.1)*
- L40 `#6` `        color: AppTheme.darkSurface,`
- L52 excluido de #11 — `color: AppTheme.darkTextSecondary.withOpacity(0.3)` *(es `#8`)*
- L112 `#8` `                      color: AppTheme.darkTextSecondary,`
- L119 `#8` `                            color: AppTheme.darkTextSecondary,`
- L128 `#8` `                        color: AppTheme.darkTextSecondary,`
- L180 `#11` `                    foregroundColor: Colors.white,`

### `lib/presentation/widgets/client/client_ride_requesting_view.dart` *(sin uso)*
- L12 `#6` `        color: AppTheme.darkSurface,`
- L24 `#8` `              color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L49 `#8` `                  color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/client_ride_route_calculated_view.dart` *(sin uso)*
- L51 `#6` `        color: AppTheme.darkSurface,`
- L63 `#8` `              color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L92 `#8` `                            color: AppTheme.darkTextSecondary,`
- L124 `#8` `                            color: AppTheme.darkTextSecondary,`
- L189 `#10` `                foregroundColor: Colors.black,`
- L200 `#10` `                      color: Colors.black,`

### `lib/presentation/widgets/client/client_ride_initial_view.dart`
- L19 `#6` `          color: AppTheme.darkSurface, // #1A1A1A` *(el comentario menciona `#1A1A1A` en texto, no es código)*
- L59 `#11` `                      color: Colors.white,`
- L78 `#10` `                color: Colors.black,`

### `lib/presentation/widgets/client/client_ride_searching_view.dart` *(sin uso)*
- L33 `#6` `        color: AppTheme.darkSurface,`
- L45 `#8` `              color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L116 `#10` `                foregroundColor: Colors.black,`
- L127 `#10` `                      color: Colors.black,`

### `lib/presentation/widgets/client/client_ride_searching_actions_row.dart`
- L20 `#11` `          style: TextStyle(color: Colors.white),`
- L24 `#8` `          style: TextStyle(color: AppTheme.darkTextSecondary),`
- L31 excluido de #11 — `style: TextStyle(color: Colors.white70)` (variante)
- L38 `#11` `              foregroundColor: Colors.white,`
- L94 `#11` `                    color: canAct ? Colors.white : Colors.white38,`
- L144 excluido de #11 — `color: canAct ? Colors.white70 : Colors.white38` (variantes)
- L197 excluido de #11 — `color: borderColor ?? Colors.white24` (borde, variante)

### `lib/presentation/widgets/client/client_ride_driver_attention_banner.dart`
- L36 `#11` `                color: Colors.white,`

### `lib/presentation/widgets/client/map_route_summary_bar.dart`
- L86 excluido de #11 — `color: Colors.white.withValues(alpha: 0.35)` (línea conectora decorativa)
- L204 `#10` `            color: Colors.black.withValues(alpha: 0.6),`
- L207 excluido de #11 — `color: Colors.white.withValues(alpha: 0.1)` (borde del contenedor "cristal")
- L224 `#11` `                      color: Colors.white,`
- L243 excluido de #11 — `highlightColor: Colors.white.withValues(alpha: 0.06)` (efecto de toque)
- L264 `#11` `                                      color: Colors.white,`
- L276 `#11` `                                      color: Colors.white,`

### `lib/presentation/widgets/client/map/client_map_layer.dart`
- L1425 `#8` `                color: AppTheme.darkTextSecondary,`
- L1675 `#6` `                color: AppTheme.darkSurface,`
- L1730 `#10` `                    color: Colors.black.withValues(alpha: 0.35),`
- L1742 `#11` `                  color: Colors.white,`
- L1759 `#4` `            color: const Color(0xFF121212),`
- L1763 `#10` `                color: Colors.black.withValues(alpha: 0.35),`
- L1777 `#11` `              color: Colors.white,`
- L1788 `#10` `            color: Colors.black.withValues(alpha: 0.28),`

### `lib/presentation/widgets/client/panels/driver_arrived_panel.dart`
- L28 excluido de #11 — `color: Colors.white24` (barra de arrastre)
- L48 `#11` `                      color: Colors.white,`
- L56 `#8` `                  color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/panels/driver_assigned_panel.dart`
- L28 excluido de #11 — `color: Colors.white24` (barra de arrastre)
- L57 `#11` `                            color: Colors.white,`
- L68 `#8` `                  color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/panels/negotiating_panel.dart`
- L62 `#10` `              color: Colors.black.withValues(alpha: 0.05),`
- L77 excluido de #11 — `border: Border.all(color: Colors.white12)`
- L89 `#11` `                              color: Colors.white,`
- L179 excluido de #11 — `border: Border.all(color: Colors.white12)`
- L198 `#8` `                    color: AppTheme.darkTextSecondary,`
- L254 `#11` `                        color: Colors.white,`
- L263 `#8` `                        color: AppTheme.darkTextSecondary,`
- L272 excluido de #11 — `color: Colors.white70` (variante)
- L281 `#8` `                          color: AppTheme.darkTextSecondary,`
- L301 `#10`/`#11` `                    foregroundColor: Colors.white70,` *(variante — no cuenta en #11 exacto)*
- L302 `#2` `                    backgroundColor: const Color(0xFF2A2A2A),`
- L332 `#10` `                    foregroundColor: Colors.black,`
- L348 `#6` (referencia indirecta) `                            AppTheme.darkSurface,`

### `lib/presentation/widgets/client/panels/ready_to_request_panel.dart`
- L54 `#6` `      color: AppTheme.darkSurface,`
- L61 excluido de #11 — `highlightColor: Colors.white.withValues(alpha: 0.06)`
- L76 `#8` `              color: AppTheme.darkTextSecondary.withValues(alpha: 0.85),`
- L133 excluido de #11 — `border: Border.all(color: Colors.white24)`
- L142 `#6` `                    color: AppTheme.darkSurface,`
- L176 `#6` `                    color: AppTheme.darkSurface,`
- L204 `#8` `                    color: AppTheme.darkTextSecondary,`
- L235 `#8` `            color: AppTheme.darkTextSecondary,`
- L319 `#6` (referencia) `                  : AppTheme.darkSurface,`
- L322 excluido de #11 — `Colors.white12` (variante, borde)
- L332 `#11` `                  color: selected ? AppTheme.primaryBlue : Colors.white70,` *(ícono, pero variante `.white70` → excluida por ser variante, no `Colors.white` exacto)*
- L342 `#11` `                          color: Colors.white,`
- L352 `#8` `                          color: AppTheme.darkTextSecondary,`
- L371 `#11` `                          color: selected ? AppTheme.primaryBlue : Colors.white,`
- L380 `#8` `                          color: AppTheme.darkTextSecondary,`
- L389 `#11` `                        color: Colors.white.withValues(alpha: 0.45),`
- L418 `#10` `          shadowColor: Colors.black54,`
- L430 `#6` `                      color: AppTheme.darkSurface,`
- L467 `#10` `                        foregroundColor: Colors.black,`
- L481 `#10` `                                  Colors.black,`
- L500 `#6` `                      color: AppTheme.darkSurface,`
- L637 `#10` `              shadowColor: Colors.black54,`
- L650 `#1` `                      color: Color(0xFF1A1A1A),`
- L697 `#8` `                                    color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/panels/search_location_panel.dart`
- L38 excluido de #11 — `color: Colors.white24` (barra de arrastre)
- L59 `#11` `          style: const TextStyle(color: Colors.white),`
- L62 `#6` `            fillColor: AppTheme.darkSurface,`
- L65 `#8` `            hintStyle: TextStyle(color: AppTheme.darkTextSecondary),`
- L82 `#11` `          style: const TextStyle(color: Colors.white),`
- L85 `#6` `            fillColor: AppTheme.darkSurface,`
- L88 `#8` `            hintStyle: TextStyle(color: AppTheme.darkTextSecondary),`
- L103 `#8` `              color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),`
- L125 `#11` `                    color: Colors.white,`
- L150 `#10` `                foregroundColor: Colors.black,`
- L173 `#8` `              color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),`
- L195 `#6` `                    color: AppTheme.darkSurface.withValues(alpha: 0.65),`
- L198 excluido de #11 — `Colors.white.withValues(alpha: 0.07)` (borde)
- L221 `#11` `                                color: Colors.white,`
- L232 `#8` `                                color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/panels/searching_driver_panel.dart`
- L79 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L83 `#11` `          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),`
- L87 `#8` `          style: TextStyle(color: AppTheme.darkTextSecondary),`
- L94 excluido de #11 — `Colors.white54` (variante)
- L196 excluido de #11 — `Colors.white24` (barra)
- L214 `#11` `                      color: Colors.white,`
- L227 excluido de #11 — `Colors.white54` (variante)
- L236 `#11` `                        color: Colors.white,`
- L253 excluido de #11 — `Border.all(color: Colors.white24)`
- L263 `#6` `                        color: AppTheme.darkSurface,`
- L292 excluido de #11 — `: Colors.white24` (ícono deshabilitado, variante)
- L302 `#11` `                            color: Colors.white,`
- L311 `#6` `                        color: AppTheme.darkSurface,`
- L346 `#10` `                        foregroundColor: Colors.black,`
- L348 `#6` `                            AppTheme.darkSurface,`
- L349 excluido de #11 — `disabledForegroundColor: Colors.white24` (variante)

### `lib/presentation/widgets/client/panels/trip_finished_panel.dart`
- L29 excluido de #11 — `Colors.white24` (barra)
- L38 excluido de #11 — `Border.all(color: Colors.white12)`
- L51 `#11` `                      color: Colors.white,`
- L60 `#8` `                  color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/panels/trip_ongoing_panel.dart`
- L28 excluido de #11 — `Colors.white24` (barra)
- L35 `#11` `                color: Colors.white,`
- L44 `#8` `            color: AppTheme.darkTextSecondary,`

### `lib/presentation/widgets/client/panels/driver_assigned_panel.dart` — *(ya listado arriba)*

---

### `lib/presentation/screens/splash/splash_screen.dart`
- L41 `#5` `        backgroundColor: AppTheme.darkBackground,`

### `lib/presentation/screens/login/login_screen.dart`
- L81 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L94 `#8` `                      color: AppTheme.darkTextSecondary,`
- L148 `#6` `                    fillColor: AppTheme.darkSurface,`
- L166 `#8` `                            color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L173 `#8` `                      color: AppTheme.darkTextSecondary,`
- L191 `#10` `                  foregroundColor: Colors.black,`
- L215 `#8` `                      color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L227 `#8` `                      color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L276 `#6` `          color: AppTheme.darkSurface,`
- L279 `#8` `            color: AppTheme.darkTextSecondary.withOpacity(0.2),`

### `lib/presentation/screens/sms_verification/sms_verification_screen.dart`
- L289 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L383 `#6` `                          fillColor: AppTheme.darkSurface,`
- L425 `#10` `                    foregroundColor: Colors.black,`
- L439 `#10` `                                AlwaysStoppedAnimation<Color>(Colors.black),`
- L458 `#8` `                                    color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/register/client_register_screen.dart`
- L48 `#10` `        onPrimary: Colors.black,`
- L49 `#6` `        surface: AppTheme.darkSurface,`
- L53 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L133 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L175 `#8` `                        const TextStyle(color: AppTheme.darkTextSecondary),`
- L177 `#6` `                    fillColor: AppTheme.darkSurface,`
- L198 `#8` `                            color: AppTheme.darkTextSecondary`
- L290 `#8` `                              : AppTheme.darkTextSecondary,`
- L346 `#10` `                    foregroundColor: Colors.black,`
- L359 `#10` `                                AlwaysStoppedAnimation<Color>(Colors.black),`
- L402 `#8` `      labelStyle: const TextStyle(color: AppTheme.darkTextSecondary),`
- L405 `#6` `      fillColor: AppTheme.darkSurface,`

### `lib/presentation/screens/register/driver_register_screen.dart`
- L81 `#6` `      backgroundColor: AppTheme.darkSurface,`
- L132 `#8` `            color: AppTheme.darkTextSecondary,`
- L138 `#6` `          color: AppTheme.darkSurface,`
- L169 `#8` `                            color: AppTheme.darkTextSecondary.withValues(`
- L205 `#10` `        onPrimary: Colors.black,`
- L206 `#6` `        surface: AppTheme.darkSurface,`
- L210 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L237 `#8` `      labelStyle: const TextStyle(color: AppTheme.darkTextSecondary),`
- L239 `#8` `        color: AppTheme.darkTextSecondary.withValues(alpha: 0.7),`
- L243 `#6` `      fillColor: AppTheme.darkSurface,`
- L274 `#8` `                  : AppTheme.darkTextSecondary,`
- L436 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L456 `#6` `                    backgroundColor: AppTheme.darkSurface,`
- L513 `#8` `                      const TextStyle(color: AppTheme.darkTextSecondary),`
- L515 `#6` `                  fillColor: AppTheme.darkSurface,`
- L537 `#8` `                              AppTheme.darkTextSecondary.withValues(alpha: 0.3),`
- L628 `#10` `                    foregroundColor: Colors.black,`
- L760 `#10` `                      foregroundColor: Colors.black,`
- L856 `#6` `              dropdownColor: AppTheme.darkSurface,`
- L867 `#8` `                style: TextStyle(color: AppTheme.darkTextSecondary),`
- L943 `#10` `                      foregroundColor: Colors.black,`
- L955 `#10` `                              color: Colors.black,`

### `lib/presentation/screens/auth/register_profile_screen.dart`
- L72 `#1` `  static const Color _inactive = Color(0xFF1A1A1A);`
- L196 `#10` `        onPrimary: Colors.black,`
- L197 `#6` `        surface: AppTheme.darkSurface,`
- L201 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L245 excluido de #11 — `Colors.white70` (variante)
- L252 excluido de #11 — `Colors.white70` (variante)
- L259 excluido de #11 — `Colors.white : Colors.white70` *(el `Colors.white` puro sí cuenta → `#11` INCLUIDO)*
- L421 `#11` `        style: const TextStyle(color: Colors.white),`
- L424 excluido — `Colors.white70` (variante)
- L436 `#11` `        style: const TextStyle(color: Colors.white),`
- L440 excluido — `Colors.white70`
- L474 `#11` `          style: const TextStyle(color: Colors.white),`
- L478 excluido — `Colors.white70`
- L498 `#11` `          style: const TextStyle(color: Colors.white),`
- L506 excluido — `Colors.white70`
- L528 excluido — `Colors.white70`
- L537 excluido — `Colors.white70`
- L548 `#11` `                      _clientBirthDate != null ? Colors.white : Colors.white70,`
- L567 `#11` `          style: const TextStyle(color: Colors.white),`
- L571 excluido — `Colors.white70`
- L574 excluido — `Colors.white70`
- L595 `#11` `          style: const TextStyle(color: Colors.white),`
- L603 excluido — `Colors.white70`
- L606 excluido — `Colors.white70`
- L627 `#11` `          style: const TextStyle(color: Colors.white),`
- L631 excluido — `Colors.white70`
- L634 excluido — `Colors.white70`
- L649 `#11` `          style: const TextStyle(color: Colors.white),`
- L653 excluido — `Colors.white70`
- L656 excluido — `Colors.white70`
- L671 `#11` `          style: const TextStyle(color: Colors.white),`
- L678 excluido — `Colors.white70`
- L681 excluido — `Colors.white70`
- L696 `#11` `          style: const TextStyle(color: Colors.white),`
- L706 excluido — `Colors.white70.withValues(alpha: 0.65)` (variante)
- L708 excluido — `Colors.white70`
- L711 excluido — `Colors.white70`
- L772 `#11` `            color: Colors.white,`
- L777 excluido — `Colors.white70`
- L780 excluido — `Colors.white70`
- L791 excluido — `Colors.white70` (sin `const`)
- L810 `#11` `          style: const TextStyle(color: Colors.white),`
- L813 excluido — `Colors.white70`
- L816 excluido — `Colors.white70`
- L898 `#11` `                                  color: Colors.white,`
- L911 excluido — `Colors.white70`
- L921 excluido — `Colors.white70`
- L946 `#10` `                              foregroundColor: Colors.black,`
- L960 `#10` `                                        Colors.black,`
- L1009 excluido — `Colors.white70`

### `lib/presentation/screens/auth/driver_approval_screen.dart`
- L31 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L49 `#11` `                      color: Colors.white,`
- L59 `#8` `                      color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/driver/become_driver_screen.dart`
- L113 `#10` `              onPrimary: Colors.black,`
- L114 `#6` `              surface: AppTheme.darkSurface,`
- L128 `#6` `      backgroundColor: AppTheme.darkSurface,`
- L356 `#8` `      hintStyle: const TextStyle(color: AppTheme.darkTextSecondary),`
- L383 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L452 `#5` `            backgroundColor: AppTheme.darkBackground,`
- L454 `#5` `              backgroundColor: AppTheme.darkBackground,`
- L482 `#10` `                          foregroundColor: Colors.black,`
- L608 `#8` `                            style: TextStyle(color: AppTheme.darkTextSecondary),`
- L820 `#10` `                color: Colors.black54,`
- L831 `#11` `                        style: TextStyle(color: Colors.white),`
- L903 `#8` `                        color: AppTheme.darkTextSecondary,`
- L912 `#8` `                            : AppTheme.darkTextSecondary,`
- L919 `#8` `              const Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),`

### `lib/presentation/screens/driver/driver_rejected_documents_screen.dart`
- L52 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L63 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L105 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L115 `#8` `                    style: TextStyle(color: AppTheme.darkTextSecondary),`
- L128 `#6` `                        color: AppTheme.darkSurface,`
- L149 `#8` `                                            color: AppTheme.darkTextSecondary,`
- L191 `#10` `                                            color: Colors.black,`
- L213 `#6` `      backgroundColor: AppTheme.darkSurface,`

### `lib/presentation/screens/driver/driver_route_placeholder_screen.dart`
- L17 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L20 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L30 `#8` `                  color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart`
- L576 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L681 `#8` `                                color: AppTheme.darkTextSecondary,`
- L733 `#10` `                      color: Colors.black.withValues(alpha: 0.6),`
- L741 `#11` `                            color: Colors.white,`
- L788 `#6` `                          backgroundColor: AppTheme.darkSurface,`
- L864 `#6` `        color: AppTheme.darkSurface,`
- L867 `#10` `            color: Colors.black,`
- L880 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L933 `#6` `            color: AppTheme.darkSurface.withOpacity(0.95),`
- L937 `#10` `                color: Colors.black.withOpacity(0.3),`
- L949 `#8` `                color: AppTheme.darkTextSecondary,`
- L979 `#6` `          color: AppTheme.darkSurface.withOpacity(0.95),`
- L983 `#10` `              color: Colors.black.withOpacity(0.3),`
- L1043 `#8` `                              color: AppTheme.darkTextSecondary,`
- L1049 `#8` `                                    color: AppTheme.darkTextSecondary,`
- L1101 `#6` `          color: AppTheme.darkSurface.withOpacity(0.95),`
- L1105 `#10` `              color: Colors.black.withOpacity(0.3),`
- L1150 `#10` `          foregroundColor: Colors.white,` *(nota: es `#11`, ver más abajo — corregido)*
- L1175 `#10` `          foregroundColor: Colors.black,`
- L1200 `#11` `          foregroundColor: Colors.white,`
- L1229 `#6` `        color: AppTheme.darkSurface.withOpacity(0.96),`
- L1233 `#10` `            color: Colors.black.withOpacity(0.4),`
- L1263 `#8` `                const Icon(Icons.person_outline, size: 18, color: AppTheme.darkTextSecondary),`
- L1269 `#8` `                          color: AppTheme.darkTextSecondary,`
- L1304 `#8` `                    color: AppTheme.darkTextSecondary,`
- L1410 excluido de #11 — punto de estado (`isAvailableOnline ? Colors.white : Colors.grey[400]`, gráfico no textual)
- L1414 excluido de #11 — mismo punto de estado, sombra
- L1426 `#10` `                color: Colors.black,`
- L1509 `#6` `            color: AppTheme.darkSurface.withOpacity(0.95),`
- L1513 `#10` `                color: Colors.black.withOpacity(0.3),`
- L1531 `#8` `                color: AppTheme.darkTextSecondary.withOpacity(0.3),`
- L1601 `#11` `        label: Colors.white,` *(color de texto del chip de pago)*
- L1607 `#11` `        label: Colors.white,`
- L1613 `#11` `        label: Colors.white,`
- L1640 `#8` `      color: AppTheme.darkTextSecondary,`
- L1664 `#1` `    const cardBg = Color(0xFF1A1A1A);`
- L1716 excluido de #11 — `Colors.white.withValues(alpha: 0.06)` (borde de tarjeta)

*(Corrección: la línea 1150 de este archivo es `foregroundColor: Colors.white,` — pertenece al patrón `#11`, no `#10`; quedó mal etiquetada arriba en la primera pasada, se corrige aquí.)*

### `lib/presentation/screens/driver_profile/driver_profile_screen.dart`
- L16 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L18 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L75 `#6` `            color: AppTheme.darkSurface,`
- L79 excluido de #11 — `Colors.white.withValues(alpha: 0.06)` (borde)
- L100 `#8` `                  color: AppTheme.darkTextSecondary,`
- L128 `#6` `            color: AppTheme.darkSurface,`
- L132 excluido de #11 — borde
- L153 `#8` `                  color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/driver_help/driver_help_screen.dart`
- L13 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L16 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L52 `#6` `        color: AppTheme.darkSurface,`
- L57 excluido de #11 — borde
- L70 `#8` `            color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/driver_settings/driver_settings_screen.dart`
- L15 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L18 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L34 `#6` `                color: AppTheme.darkSurface,`
- L38 excluido de #11 — borde
- L54 `#8` `                    style: const TextStyle(color: AppTheme.darkTextSecondary),`
- L58 `#8` `                    color: AppTheme.darkTextSecondary,`
- L69 `#6` `            color: AppTheme.darkSurface,`
- L73 excluido de #11 — borde
- L86 `#8` `                style: TextStyle(color: AppTheme.darkTextSecondary),`
- L88 `#8` `              trailing: Icon(Icons.map_outlined, color: AppTheme.darkTextSecondary),`
- L95 `#6` `            color: AppTheme.darkSurface,`
- L99 excluido de #11 — borde
- L116 `#8` `                  color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),`
- L126 `#6` `            color: AppTheme.darkSurface,`
- L130 excluido de #11 — borde
- L164 `#6` `      backgroundColor: AppTheme.darkSurface,`
- L202/208/215/221/228/234 — `RadioListTile` del selector de tema agregado en la tarea anterior (`ThemeMode`, sin relación con estos patrones)
- L253 `#8` `            color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/driver_support/driver_support_screen.dart`
- L13 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L16 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L28 `#6` `            color: AppTheme.darkSurface,`
- L32 excluido de #11 — borde
- L55 `#8` `                  color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),`
- L61 `#8` `                color: AppTheme.darkTextSecondary,`
- L102 `#6` `      color: AppTheme.darkSurface,`
- L107 excluido de #11 — borde
- L120 `#8` `          color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/driver_wallet/driver_wallet_screen.dart`
- L19 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L22 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L44 `#6` `                    color: AppTheme.darkSurface,`
- L54 `#8` `                              color: AppTheme.darkTextSecondary,`
- L72 `#8` `                          color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),`
- L90 `#10` `                            foregroundColor: Colors.black,`
- L148 `#6` `        color: AppTheme.darkSurface,`
- L150 excluido de #11 — borde

### `lib/presentation/screens/history/ride_history_screen.dart`
- L29 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L32 `#6` `          backgroundColor: AppTheme.darkSurface,`
- L92 `#8` `                        color: AppTheme.darkTextSecondary.withValues(alpha: 0.6),`
- L107 `#8` `                              color: AppTheme.darkTextSecondary,`
- L188 `#6` `      color: AppTheme.darkSurface,`
- L192 excluido de #11 — borde
- L205/216/222 `#8` `                      color: AppTheme.darkTextSecondary,` (×3)

### `lib/presentation/screens/client_dashboard/client_dashboard_screen.dart`
- L93 `#5` `            backgroundColor: AppTheme.darkBackground,`

### `lib/presentation/screens/client/client_profile_screen.dart`
- L10 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L12 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L71 `#8` `                          color: AppTheme.darkTextSecondary,`
- L83 `#6` `                  color: AppTheme.darkSurface,`
- L129 `#10` `                    foregroundColor: Colors.black,`
- L173 `#8` `                      color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/client/client_wallet_screen.dart`
- L11 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L13 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L32 `#6` `                  color: AppTheme.darkSurface,`
- L44 `#8` `                            color: AppTheme.darkTextSecondary,`
- L119 `#6` `        color: AppTheme.darkSurface,`
- L169 `#10` `                            color: Colors.black,`
- L183 `#8` `                          color: AppTheme.darkTextSecondary,`
- L192 `#8` `            color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/client/client_trips_screen.dart`
- L36 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L38 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L54 `#8` `                      color: AppTheme.darkTextSecondary,`
- L60 `#8` `                            color: AppTheme.darkTextSecondary,`
- L83 `#6` `        color: AppTheme.darkSurface,`
- L98 `#8` `                    color: AppTheme.darkTextSecondary,`
- L104 `#8` `                          color: AppTheme.darkTextSecondary,`
- L161 `#8` `              color: AppTheme.darkTextSecondary.withOpacity(0.3),`

### `lib/presentation/screens/client/client_favorites_screen.dart`
- L29 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L71 `#10` `              foregroundColor: Colors.black,`
- L83 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L85 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L101 `#8` `                      color: AppTheme.darkTextSecondary,`
- L107 `#8` `                            color: AppTheme.darkTextSecondary,`
- L125 `#10` `        child: const Icon(Icons.add, color: Colors.black),`
- L135 `#6` `        color: AppTheme.darkSurface,`
- L169 `#8` `                        color: AppTheme.darkTextSecondary,`
- L177 `#8` `            color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/client/client_help_screen.dart`
- L13 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L16 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L52 `#6` `        color: AppTheme.darkSurface,`
- L57 excluido de #11 — borde
- L70 `#8` `            color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/client/client_support_screen.dart`
- L13 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L16 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L28 `#6` `            color: AppTheme.darkSurface,`
- L32 excluido de #11 — borde
- L55 `#8` `                  color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),`
- L61 `#8` `                color: AppTheme.darkTextSecondary,`
- L102 `#6` `      color: AppTheme.darkSurface,`
- L107 excluido de #11 — borde
- L120 `#8` `          color: AppTheme.darkTextSecondary,`

### `lib/presentation/screens/client/client_settings_screen.dart`
- L13 `#5` `      backgroundColor: AppTheme.darkBackground,`
- L15 `#5` `        backgroundColor: AppTheme.darkBackground,`
- L118 `#11` `                  foregroundColor: Colors.white,`
- L150 `#6` `        color: AppTheme.darkSurface,`
- L171 `#8` `                  color: AppTheme.darkTextSecondary,`
- L180 `#8` `                    color: AppTheme.darkTextSecondary,`
- L203 `#6` `      backgroundColor: AppTheme.darkSurface,`
- L241/247/254/260/267/273 — `RadioListTile` del selector de tema (tarea anterior)
- L292 `#6` `        backgroundColor: AppTheme.darkSurface,`
- L299 `#8` `          style: TextStyle(color: AppTheme.darkTextSecondary),`
- L313 `#11` `              foregroundColor: Colors.white,`

---

## Nota sobre `AppTheme.darkSurface` (patrón #6)

El patrón se buscó con límite de palabra (`\b`) para no confundir con `AppTheme.darkSurfaceElevated` (una constante distinta, no pedida en la lista). Ningún archivo usa `darkSurfaceElevated` fuera de su propia definición en `app_theme.dart` — **excepto** que si se necesitara esa variante también, avisar y se agrega en una pasada aparte.

## Totales

- **10 archivos** usan `Color(0xFF1A1A1A)` directamente en vez de `AppTheme.darkSurface`, pese a ser el mismo valor — código legacy que no pasa por la constante compartida (candidato directo para la "pasada separada" de theming).
- **`AppTheme.darkSurface`** y **`AppTheme.darkTextSecondary`** son, por lejos, los patrones más repetidos (95 y 141 apariciones) — son los dos puntos de mayor esfuerzo si se migra a colores conscientes del tema.
- Varios de los archivos con más coincidencias (`client_ride_active_view.dart`, `client_ride_requesting_view.dart`, `client_ride_route_calculated_view.dart`, `client_ride_searching_view.dart`) son los **widgets sin uso** ya identificados en `PROJECT_REPORT.md` §6.1 — no requieren migración si se eliminan en lugar de mantenerse.
