# Flujo Visual: Qué ve un usuario nuevo, pantalla por pantalla

*Basado en la lectura completa de: [splash_screen.dart](lib/presentation/screens/splash/splash_screen.dart), [login_screen.dart](lib/presentation/screens/login/login_screen.dart), [sms_verification_screen.dart](lib/presentation/screens/sms_verification/sms_verification_screen.dart), [client_register_screen.dart](lib/presentation/screens/register/client_register_screen.dart), [driver_register_screen.dart](lib/presentation/screens/register/driver_register_screen.dart), [register_profile_screen.dart](lib/presentation/screens/auth/register_profile_screen.dart), [driver_approval_screen.dart](lib/presentation/screens/auth/driver_approval_screen.dart), [auth_bloc.dart](lib/presentation/bloc/auth/auth_bloc.dart), [auth_state.dart](lib/presentation/bloc/auth/auth_state.dart), [app_router.dart](lib/core/routes/app_router.dart).*

> ⚠️ **Nota importante antes de leer el diagrama**: en el código actual, `LoginScreen` **no tiene ningún botón que lleve a `/client-register` ni a `/driver-register`** (verificado por búsqueda de referencias — ver [APP_FLOW.md §6](APP_FLOW.md)). El único camino realmente conectado desde `LoginScreen` es el genérico por OTP, que **siempre termina registrando un CLIENTE** (no hay selector de rol en `RegisterProfileScreen` cuando se llega sin `prefilledRole`). Las pantallas `ClientRegisterScreen` y `DriverRegisterScreen` están 100 % implementadas y sí producen el registro correcto de cada rol, pero hoy solo son alcanzables por *deep link* directo a `/client-register` o `/driver-register`, no desde un botón visible en la app. Este documento muestra **ambos caminos tal como están programados**, marcando con 🔗 cuál es el que de verdad se dispara desde `LoginScreen` hoy.

---

## Mapa general

```
                              ┌─────────────────┐
                              │  SplashScreen   │  (siempre, para todos)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   LoginScreen   │  (compartida)
                              └────────┬────────┘
                    🔗 único camino conectado desde aquí
                                       ▼
                              ┌──────────────────────┐
                              │ SmsVerificationScreen │  (compartida, role="")
                              └───────────┬───────────┘
                                          ▼
                              ┌──────────────────────┐
                              │ RegisterProfileScreen │  (compartida, sin selector)
                              │   → SIEMPRE role='client'
                              └───────────┬───────────┘
                                          ▼
                              ┌──────────────────────┐
                              │  ClientDashboardScreen │
                              └────────────────────────┘


  Caminos alternativos, implementados pero SIN botón de entrada verificado hoy:

  ┌───────────────────────┐                      ┌───────────────────────┐
  │  ClientRegisterScreen  │  (/client-register)  │  DriverRegisterScreen  │  (/driver-register)
  └───────────┬────────────┘                      └───────────┬────────────┘
              ▼                                                ▼
   SmsVerificationScreen (role=client)              SmsVerificationScreen (role=driver)
              ▼                                                ▼
   RegisterProfileScreen (bloqueada,                RegisterProfileScreen (bloqueada,
   banner "Registro como pasajero")                 banner "Registro como conductor")
              ▼                                                ▼
   ClientDashboardScreen                            DriverApprovalScreen (is_approved=false)
                                                                 ▼
                                                      … espera aprobación ERP …
                                                                 ▼
                                                      DriverDashboardScreen
```

---

## TRAMO COMPARTIDO (idéntico para ambos roles)

```
═══════════════════════════════════════════════════════
  PASO 0 — Arranque
═══════════════════════════════════════════════════════

📱 PANTALLA 1: SplashScreen
   Archivo: lib/presentation/screens/splash/splash_screen.dart

   Ve:
     • Logo dibujado a mano con CustomPainter (una "L" con una flecha, en
       cian #00D4FF) — LlevaLogoPainter, líneas 78-117
     • Texto "Lleva Trujillo" (displaySmall, azul, negrita, letterSpacing 2)
     • Un CircularProgressIndicator pequeño (20×20) debajo
     • Fondo negro (AppTheme.darkBackground)
     • NINGÚN botón — pantalla 100% automática

   Dispara automáticamente en build():
     context.read<AuthBloc>().add(const CheckAuthStatus())     [L22-25]
     (protegido por bandera _requested para no repetirse en cada rebuild)

   Estado AuthBloc:
     AuthLoading  →  luego  →  AuthInitial
     (auth_bloc.dart:173-202 — no hay sesión Supabase Auth activa)

   Siguiente pantalla: LoginScreen
   Por qué: BlocListener de SplashScreen [L36-37]:
     "if (state is AuthInitial || state is AuthError) context.go('/login');"
     El redirect del GoRouter NO interviene aquí — '/login' está en
     _isPublicPath, así que _authRedirect simplemente deja pasar.
        │
        ▼
```

```
═══════════════════════════════════════════════════════
  PASO 1 — Ingreso de teléfono
═══════════════════════════════════════════════════════

📱 PANTALLA 2: LoginScreen
   Archivo: lib/presentation/screens/login/login_screen.dart

   Ve:
     • "Bienvenido a" (gris, headlineMedium)
     • "Lleva" (azul cian, displayLarge, bold)               [L66-79]
     • "Comisiones justas para conductores" (bodyMedium)
     • Campo de teléfono con prefijo fijo "+51" + separador vertical,
       placeholder "Número de celular", solo dígitos, máx. 9   [L109-156]
     • Botón "Continuar" (fondo cian, texto negro)             [L162-181]
     • Separador "O continúa con"
     • Dos botones sociales "Google" y "Apple" — SIN funcionalidad,
       onTap vacío con comentario // TODO                      [L214-230]

   Al tocar "Continuar" → _handleContinue()  [L35-51]:
     • Si el número tiene menos de 9 dígitos:
         SnackBar rojo "Por favor ingresa un número de celular válido"
         (se queda en esta pantalla)
     • Si es válido:
         context.push('/sms-verification?phone=$phoneNumber&role=')
         ⚠️ nótese role= VACÍO — LoginScreen nunca sabe (ni pregunta)
         si el usuario quiere ser cliente o conductor.

   Evento AuthBloc: NINGUNO todavía (solo se navega).
   Siguiente pantalla: SmsVerificationScreen
        │
        ▼
```

```
═══════════════════════════════════════════════════════
  PASO 2 — Verificación por SMS (código real de Supabase Auth)
═══════════════════════════════════════════════════════

📱 PANTALLA 3: SmsVerificationScreen
   Archivo: lib/presentation/screens/sms_verification/sms_verification_screen.dart

   Ve:
     • "Verificación" (displaySmall, azul, bold)
     • "Ingresa el código de 6 dígitos que enviamos a"
     • "+51 {phoneNumber}" (azul, bold)                         [L303-322]
     • 6 casillas de 56×56 px, una por dígito, con autoavance de foco
       al escribir y auto-envío al completar el 6º dígito        [L167-178]
     • Botón "Verificar" (con spinner mientras _isVerifying)     [L386-415]
     • Abajo: "Reenviar código en {n}s" (cuenta regresiva de 60s)
       o botón "Reenviar código" una vez llega a 0                [L417-437]

   Al montar (initState, antes de que el usuario haga nada):
     • PendingDriverDocuments.load() — intenta cargar rutas de fotos
       guardadas previamente (solo aplica si viene del flujo conductor
       dedicado; para el camino genérico esto resuelve a null)     [L77-84]
     • postFrameCallback dispara:
         AuthBloc.add(SendOtpRequested(widget.phoneNumber))        [L89-92]

   Evento AuthBloc: SendOtpRequested(phone)
   → AuthBloc._onSendOtpRequested [auth_bloc.dart:73-100]:
       emit(AuthLoading) → _supabase.auth.signInWithOtp(phone: '+51...')
       → emit(AuthOtpSent(phone))
   Efecto en pantalla: SnackBar verde "Código enviado por SMS", se
   reinicia el contador de 60s [sms_verification_screen.dart:214-225].

   Usuario escribe los 6 dígitos → _handleVerify() → 
     AuthBloc.add(OtpVerified(phone: phoneNumber, code: code))

   AuthBloc._onOtpVerified [auth_bloc.dart:102-164]:
     • verifyOTP(phone, token: code, type: OtpType.sms) — código real
       validado contra Supabase, no simulado
     • Busca perfil por auth.uid() → no existe (usuario nuevo)
     • Busca perfil por teléfono (compatibilidad legacy) → tampoco existe
     • emit(AuthNeedsRegistration(phone))                         [L145]

   Si el código es incorrecto/expirado → AuthBloc emite AuthError(msg)
   → SnackBar rojo con el mensaje, se reactiva el botón "Verificar".

   Siguiente pantalla: depende de qué llegó en los query params de la
   URL con la que se abrió esta pantalla (ver bifurcación abajo).
```

---

## 🔀 AQUÍ SE BIFURCA EL FLUJO

`SmsVerificationScreen`, al recibir `AuthNeedsRegistration`, decide a dónde navegar según dos funciones (`_isDriverFullPackage()` [L180-198] y `_isClientFullPackage()` [L200-208]) que revisan si **todos** los campos de un registro completo llegaron por query params/`extra`:

```
                         AuthNeedsRegistration(phone)
                                    │
                     ¿role/campos venían completos?
              ┌─────────────────────┼─────────────────────┐
              │                     │                      │
     _isDriverFullPackage()   _isClientFullPackage()   ninguno completo
        == true                  == true              (camino genérico,
              │                     │                   role vacío)
              ▼                     ▼                      ▼
     push('/register',      push('/register',      push('/register',
       extra: {Map          extra: {Map              extra: phone
       completo driver})    completo client})         [String]!)
              │                     │                      │
              ▼                     ▼                      ▼
     RegisterProfileScreen  RegisterProfileScreen   RegisterProfileScreen
     prefilledRole='driver' prefilledRole='client'  prefilledRole=null
     (BLOQUEADA)             (BLOQUEADA)              (ABIERTA, formulario
                                                       manual, rol fijo
                                                       en 'client')
```

🔗 **El camino real desde `LoginScreen` cae siempre en la tercera columna** (role vacío → `RegisterProfileScreen` con `prefilledRole: null` → `_selectedRole` se inicializa en `'client'` y **no existe ningún control en pantalla para cambiarlo** — [register_profile_screen.dart:152, 460-469](lib/presentation/screens/auth/register_profile_screen.dart#L152-L469)).

Las columnas 1 y 2 solo se alcanzan si se llegó a `SmsVerificationScreen` con los query params ya completos — lo que en el código solo ocurre viniendo de `ClientRegisterScreen` o `DriverRegisterScreen` (ver más abajo).

---

## COLUMNA A — Nuevo CLIENTE

```
═══════════════════════════════════════════════════════
                    RUTA A1 (🔗 conectada)
═══════════════════════════════════════════════════════

📱 PANTALLA 4-A: RegisterProfileScreen (formulario abierto)
   Archivo: lib/presentation/screens/auth/register_profile_screen.dart

   Ve:
     • Botón atrás (context.pop())
     • "Crea tu perfil" (displaySmall, bold)                     [L892-901]
     • Campo "Teléfono" — de solo lectura, ya viene relleno       [L418-432]
     • Campo "Nombre completo" — editable                        [L434-458]
     • (Sin banner de rol bloqueado, porque prefilledRole es null)
     • Campos manuales porque _needsManualClientFields == true:
         - "Correo electrónico"                                   [L472-495]
         - "DNI" (8 dígitos)                                      [L496-521]
         - "Fecha de nacimiento" (selector de fecha, exige ≥18
           años vía AgeValidation.isAtLeastYearsOld)               [L522-554]
     • Botón "Comenzar" abajo, con spinner mientras
       AuthLoading/AuthUploadingDriverDocs                        [L936-976]

   Al tocar "Comenzar" → _submit() [L267-414]:
     • Valida formulario, fecha de nacimiento presente y ≥18 años
     • AuthBloc.add(RegisterUser(
         phone:, fullName:, role: 'client', email:, dni:,
         birthDate:, ...))

   AuthBloc._onRegisterUser [auth_bloc.dart:288-565], rama cliente:
     • isDriver = false → se SALTA por completo el bloque de
       subida de documentos (ese bloque es exclusivo de conductor)
     • Valida: nombre ≥5 caracteres, correo con '@' y '.', DNI
       8 dígitos numéricos, fecha de nacimiento presente y edad ≥18
       [L364-391]
     • emit(AuthLoading)                                          [L499]
     • Construye UserModel: id = authUid (de la sesión ya creada
       por verifyOTP), role:'client', isApproved: true (los
       clientes NO requieren aprobación)                          [L507-543]
     • _userRepository.createUserProfile(user) → INSERT en `profiles`
     • Si tiene éxito → emit(AuthAuthenticated(created))           [L552]
     • Si falla → emit(AuthError('No se pudo crear el perfil'))

   BlocConsumer de RegisterProfileScreen [L850-867]:
     "if (state.user.role == 'client') context.go('/client-dashboard');"

   Cómo se guarda la sesión:
     No hay ningún SharedPreferences.setString manual — la sesión
     REAL es el JWT que Supabase Auth ya persistió internamente
     desde verifyOTP() en el paso 2. No hace falta ningún paso extra.

   Redirect de seguridad (_authRedirect, rama pasajero
   [app_router.dart:152-156]): usuario autenticado, rol cliente,
   sin capacidad de alternar a conductor → ninguna condición aplica
   → return null → se queda en '/client-dashboard'.
        │
        ▼
📱 PANTALLA 5-A: ClientDashboardScreen  ← primera pantalla real del cliente
   Archivo: lib/presentation/screens/client_dashboard/client_dashboard_screen.dart
   Ve: mapa de Google Maps centrado en su ubicación actual (si dio
   permiso), campo "¿A dónde vamos?", drawer con su nombre.
   Al construirse [L78-172]:
     • BlocProvider<ClientRideBloc> con dos eventos ya encolados:
         InitializePickupFromCurrentLocation  → pide GPS, hace
           reverse geocoding, fija el pin de origen              [L186-206]
         CheckActiveRide(clientId)  → busca en Supabase si ya
           tiene un viaje 'searching'/'accepted'/... — para un
           usuario recién registrado, siempre da 0 resultados,
           así que se queda en ClientRideStatus.initial            [L752-829]
     • postFrameCallback adicional: AuthBloc.add(RefreshProfileEvent())
```

```
═══════════════════════════════════════════════════════
              RUTA A2 (implementada, sin botón verificado)
═══════════════════════════════════════════════════════

📱 PANTALLA 4-A'(alt): ClientRegisterScreen  (/client-register)
   Archivo: lib/presentation/screens/register/client_register_screen.dart

   Ve:
     • AppBar "Registro de Usuario" con flecha atrás
     • "Únete a Lleva" (displaySmall, cian, bold)
     • "Crea tu cuenta y comienza a viajar" (subtítulo)
     • Campos: Teléfono (+51, 9 díg.), Nombre, Apellidos,
       DNI (8 díg.), Correo electrónico, Fecha de nacimiento
       (selector, ≥18 años)                                  [L164-296]
     • Checkbox "Acepto los términos y condiciones y la
       política de privacidad" (con enlaces resaltados)      [L298-340]
     • Botón "Continuar" (spinner 1s simulado — Future.delayed,
       NO llama a Supabase todavía)                          [L342-369]
     • Al pie: "¿Ya tienes cuenta? Inicia sesión" → context.pop()

   Al tocar "Continuar" → _handleRegister() [L74-128]:
     • Valida formulario, fecha de nacimiento, edad ≥18, términos
     • Construye un Uri hacia '/sms-verification' con TODOS los
       datos como query params:
         phone, role='client', first_name, last_name, dni,
         email, birth_date (ISO8601 UTC)
     • context.push(uri.toString())

   Evento AuthBloc: ninguno todavía (los datos viajan por la URL,
   no se ha llamado a Supabase Auth aún).

   Siguiente: SmsVerificationScreen — MISMA pantalla y MISMA lógica
   que el paso 2 de arriba, pero esta vez con role='client' y todos
   los datos personales ya presentes en los query params.

   Diferencia clave en la bifurcación: al llegar AuthNeedsRegistration,
   _isClientFullPackage() ahora es TRUE [L200-208] → 
   push('/register', extra: {Map completo}) en vez de solo el teléfono.
        │
        ▼
📱 PANTALLA 5-A': RegisterProfileScreen (BLOQUEADA)
   prefilledRole='client' → _isClientFlowLocked = true

   Ve (diferente a la ruta A1):
     • Banner cian "Registro como pasajero" (icono person)   [L465-469]
     • Subtítulo: "Confirma tu nombre y pulsa Comenzar para
       finalizar el registro."                               [L914-923]
     • Campo Teléfono (solo lectura) + Nombre completo (PRE-RELLENO
       con first_name+last_name, editable)
     • NO se muestran campos manuales — _needsManualClientFields
       es false porque _hasCompleteClientPackage ya es true
     • Botón "Comenzar"

   _submit() usa directamente los valores prefilled (no reingreso)
   → AuthBloc.add(RegisterUser(role:'client', ...todo prefilled))
   → misma lógica de AuthBloc descrita arriba → AuthAuthenticated
   → go('/client-dashboard')
        │
        ▼
   (mismo destino que Ruta A1: ClientDashboardScreen)
```

---

## COLUMNA B — Nuevo CONDUCTOR

```
═══════════════════════════════════════════════════════
     (única ruta que existe para registrar un conductor —
      sin botón de entrada verificado desde ninguna pantalla)
═══════════════════════════════════════════════════════

📱 PANTALLA 4-B: DriverRegisterScreen  (/driver-register)
   Archivo: lib/presentation/screens/register/driver_register_screen.dart
   Formulario de 3 PASOS dentro de un PageView (sin scroll lateral manual)

   ── Paso 1/3 — "Datos personales" ──
   Ve: barra de progreso (1/3), campos Teléfono (+51, 9 díg.),
   Nombre, Apellidos, Correo, DNI (8 díg.). Botón "Siguiente".
   [L491-646]

   ── Paso 2/3 — "Datos vehiculares" ──
   Ve: campos Marca, Modelo, Placa, Año de fabricación (≥2005),
   sección "Documentos del vehículo" con 2 tarjetas de foto:
     • "SOAT (foto del certificado)"
     • "Tarjeta de propiedad"
   (cada una abre un bottom sheet Galería/Cámara vía image_picker)
   Botones "Atrás" / "Siguiente".                            [L648-782]
   ⚠️ _goNext() bloquea el avance con SnackBar si SOAT o tarjeta
   de propiedad no tienen foto todavía.                       [L286-297]

   ── Paso 3/3 — "Datos para conducir" ──
   Ve: sección "Identificación y licencia" con 4 tarjetas de foto:
     • DNI — cara frontal
     • DNI — cara posterior
     • Licencia de conducir (brevete)
     • Foto de perfil del conductor
   + 3 fechas de vencimiento (SOAT, tarjeta de propiedad, revisión
   técnica) + dropdown "Categoría de licencia" (A-I/A-IIa/A-IIb/A-III)
   + campo "Número de brevete" + checkbox de términos.
   Botones "Atrás" / "Comenzar" (spinner mientras _isLoading).  [L784-975]

   Al tocar "Comenzar" → _onComenzar() [L323-431]:
     • Valida los 3 formularios, categoría de licencia, las 3 fechas,
       aceptación de términos, Y que las 6 fotos estén presentes
       (si falta alguna → SnackBar y no avanza)
     • PendingDriverDocuments.save({6 rutas locales de archivo})
       — guarda en SharedPreferences, SIN subir nada a Supabase
       todavía [L379-386]
     • Construye Uri hacia '/sms-verification' con role='driver' +
       todos los campos de texto/fecha (SIN las fotos — esas ya
       quedaron guardadas localmente)
     • context.push(uri.toString())

   Evento AuthBloc: ninguno todavía.
   Siguiente: SmsVerificationScreen (misma pantalla del Paso 2 del
   tramo compartido), esta vez con role='driver'.

   Diferencia adicional en esta pantalla: initState() carga
   PendingDriverDocuments.load() de forma async; mientras no resuelve,
   _awaitingPendingDocs es true y "Verificar" muestra el SnackBar
   "Cargando documentos, espera un momento" si se toca antes de tiempo
   [L126-135, L70-71].

   Al llegar AuthNeedsRegistration: _isDriverFullPackage() [L180-198]
   evalúa TRUE (todos los query params + PendingDriverDocuments
   .isComplete(_pendingDocPaths)) →
     push('/register', extra: {Map completo, incluyendo las 6
     rutas locales de foto esparcidas con ..._pendingDocPaths!})
        │
        ▼
📱 PANTALLA 5-B: RegisterProfileScreen (BLOQUEADA, driver)
   prefilledRole='driver' → _isDriverFlowLocked = true
   _hasCompleteDriverLegalPackage = true (todo + 6 fotos presentes)

   Ve:
     • Banner cian "Registro como conductor" (icono directions_car)
                                                                [L460-464]
     • Subtítulo: "Revisa tu nombre y confirma para enviar tu
       solicitud a revisión."                                  [L903-913]
     • Campo Teléfono (solo lectura) + Nombre completo (PRE-RELLENO,
       editable)
     • NO hay campos manuales ni selectores de foto en esta pantalla
       — todo viene ya resuelto desde el paso anterior
     • Botón "Comenzar"

   Al tocar "Comenzar" → _submit() usa TODOS los valores prefilled
   (marca, modelo, placa, año, categoría, brevete, 3 fechas, y las
   6 RUTAS LOCALES de archivo) →
     AuthBloc.add(RegisterUser(role:'driver', ...localPaths...))

   AuthBloc._onRegisterUser [auth_bloc.dart:288-565], rama conductor:
     • isDriver = true, driverWillUpload = true (hay rutas locales)
     • Como driverWillUpload es true, NO emite AuthLoading al inicio
       (evita parpadeo antes de mostrar la barra de progreso)  [L294-297]
     • Valida: nombre, correo, DNI, marca/modelo/placa, año ≥2005,
       categoría de licencia, número de brevete, las 3 fechas, y
       que las 6 rutas locales existan                        [L299-363]
     • SUBE LOS 6 DOCUMENTOS EN ESTE ORDEN FIJO, uno a la vez
       [L400-497]:
         1. dni_front  → dniFrontUrl
         2. dni_back   → dniBackUrl
         3. license    → licenseUrl
         4. soat       → soatUrl
         5. property_card → propertyCardUrl
         6. profile_pic   → profilePicUrl
       Antes de CADA subida: emit(AuthUploadingDriverDocs(
         completed: i, total: 6))  → la UI muestra la barra de
       progreso superior con texto "Subiendo documentos i/6…"
                                                            [L981-1018]
       Si algún archivo falta en disco o falla la subida (p. ej.
       RLS de Storage) → emit(AuthError(mensaje específico)) y
       SE ABORTA todo el registro — no se sube el resto ni se
       crea el perfil.
     • Tras subir las 6 → emit(AuthUploadingDriverDocs(6,6)) →
       emit(AuthLoading)                                   [L493-499]
     • Construye UserModel:
         role:'driver', isApproved: FALSE,
         dniFrontStatus/dniBackStatus/licenseStatus/soatStatus/
         propertyCardStatus = 'PENDING' (los 5)              [L521-542]
     • createUserProfile() → INSERT en `profiles`
     • Si éxito: PendingDriverDocuments.clear() (limpia
       SharedPreferences) → emit(AuthAuthenticated(created))
     • Si falla: emit(AuthError(...))

   BlocConsumer de RegisterProfileScreen: role=='driver' →
     context.go('/dashboard')

   ⚠️ PERO el redirect intercepta antes de mostrar el dashboard —
   ver siguiente pantalla.
        │
        ▼
```

---

## Pantalla de espera del conductor (y qué pasa después)

```
═══════════════════════════════════════════════════════
  El conductor NUNCA ve DriverDashboardScreen recién registrado
═══════════════════════════════════════════════════════

_authRedirect (rama conductor) [app_router.dart:122-150] intercepta
la navegación a '/dashboard':

     user.isBanned == false
     !user.isApproved == true   (recién creado, is_approved:false)
     path == '/dashboard'  →  NO es driverApprovalPath, NO empieza
     con '/client'  →  cae en:
        "if (!user.isApproved) { ... return driverApprovalPath; }"
                                                        [L135-142]

📱 PANTALLA 6-B: DriverApprovalScreen(isBanned: false)
   Archivo: lib/presentation/screens/auth/driver_approval_screen.dart

   Ve:
     • Ícono grande "reloj de arena" (Icons.hourglass_empty, cian)
     • Título: "Estamos verificando tus documentos" (bold, 22px)
     • Texto: "Tu cuenta ha sido creada exitosamente. Nuestro equipo
       está revisando tu perfil y los datos de tu vehículo para
       garantizar la seguridad de la comunidad. Te notificaremos
       pronto."                                            [L20-26]
     • Un único botón: "Cerrar sesión" (contorno cian)      [L65-88]

   Comportamiento especial:
     PopScope(canPop: false) [L28] — el gesto/botón físico de
     "atrás" NO funciona aquí. El usuario está literalmente
     atrapado en esta pantalla hasta que:
       a) toque "Cerrar sesión" → AuthBloc.add(LogoutRequested)
          → emit(AuthInitial) → context.go('/login'), o
       b) is_approved cambie a true en Supabase (ver abajo).

   Si en vez de "pendiente" el conductor está BANEADO
   (user.isBanned == true):
     Se muestra la MISMA pantalla pero con isBanned:true:
     • Ícono Icons.gpp_bad_outlined
     • Título: "Cuenta suspendida"
     • Texto: "Tu acceso como conductor ha sido suspendido. Si
       crees que es un error, contacta a soporte."
     • Mismo botón "Cerrar sesión" (única salida)
```

```
═══════════════════════════════════════════════════════
  Más tarde: el ERP externo aprueba al conductor
  (fuera de este repositorio — is_approved pasa a true en Supabase)
═══════════════════════════════════════════════════════

  Disparadores que refrescan el perfil sin que el usuario haga nada
  explícito para "comprobar si ya lo aprobaron":

    • _AuthLifecycleRefresh [main.dart:112-131] — cada vez que la
      app vuelve a primer plano (didChangeAppLifecycleState ==
      resumed) dispara AuthBloc.add(RefreshProfileEvent())
    • Cualquier pantalla que despache RefreshProfileEvent en su
      initState (p. ej. si el conductor cierra y reabre la app
      estando todavía en DriverApprovalScreen)

  AuthBloc._onRefreshProfile [auth_bloc.dart:204-224]:
    • Solo actúa si el estado actual ya es AuthAuthenticated
    • _userRepository.getUserByPhone(phone) — vuelve a leer
      `profiles` completo
    • emit(AuthAuthenticated(user))  — ahora con isApproved:true

  GoRouterRefreshCombined detecta el nuevo AuthState → reevalúa
  _authRedirect para la ruta actual ('/driver_approval'):

     shouldUseDriverHome(user, mode) sigue true (rol driver)
     user.isBanned == false
     !user.isApproved == false  (ya está aprobado, se salta esa rama)
     path == driverApprovalPath  →
        "if (path == driverApprovalPath) return '/dashboard';"
                                                        [L143-145]

📱 PANTALLA 7-B: DriverDashboardScreen  ← primera pantalla real
   del conductor, AHORA SÍ
   Archivo: lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart

   Transición automática — el conductor NO necesita cerrar sesión
   ni volver a iniciarla; en cuanto la app refresca el perfil y ve
   is_approved:true, el redirect lo saca solo de DriverApprovalScreen.

   Al construirse, GoRoute('/dashboard') [app_router.dart:276-293]
   provee MultiBlocProvider(DriverStatsCubit, DriverStatusBloc,
   DriverWalletCubit) — instancias nuevas.

   DriverDashboardScreen.initState() [L66-84]:
     • AuthBloc.add(RefreshProfileEvent())
     • DriverStatsCubit.loadTodayStats(uid)   → 0 ganancias, 0 viajes
     • DriverWalletCubit.loadWallet(uid)      → saldo 0
     • DriverStatusBloc.add(RecoverDriverActiveRide(uid))
         → para un conductor recién aprobado, no hay oferta pendiente
         ni viaje asignado → se queda en el estado inicial DriverOffline
         [driver_status_bloc.dart:24, 338-395]

   Ve: mapa centrado en su ubicación, toggle superior "No Disponible"
   (gris), FAB de menú, pestañas inferiores "Solicitudes / Zonas
   Calientes / Desempeño". El conductor debe tocar el toggle
   manualmente para empezar a recibir solicitudes (ToggleStatus).
```

---

## Resumen: pantallas compartidas vs. exclusivas de cada rol

| Pantalla | Cliente | Conductor | Compartida? |
|---|---|---|---|
| `SplashScreen` | ✅ | ✅ | Sí — idéntica, sin importar el rol |
| `LoginScreen` | ✅ | ✅ | Sí — pero solo lleva al camino que termina en cliente |
| `SmsVerificationScreen` | ✅ | ✅ | Sí — la misma pantalla y el mismo widget para ambos; solo cambian los query params con los que se abre |
| `RegisterProfileScreen` | ✅ | ✅ | Sí — misma pantalla, pero se renderiza distinto según `prefilledRole` (banner, campos manuales sí/no) |
| `ClientRegisterScreen` | ✅ | ❌ | No — exclusiva de cliente, ruta `/client-register` |
| `DriverRegisterScreen` | ❌ | ✅ | No — exclusiva de conductor, ruta `/driver-register`, único camino con subida de fotos |
| `DriverApprovalScreen` | ❌ | ✅ | No — solo la ve un conductor con `is_approved:false` o `is_banned:true` |
| `ClientDashboardScreen` | ✅ | ❌ (hasta ser aprobado y elegir modo pasajero) | No |
| `DriverDashboardScreen` | ❌ | ✅ (solo tras aprobación) | No |

## Dónde se bifurca exactamente el flujo

1. **Primera bifurcación (entrada)**: `LoginScreen` (genérico, sin rol) vs. `ClientRegisterScreen`/`DriverRegisterScreen` (formularios dedicados). Solo la primera está enlazada desde un botón real en el código leído.
2. **Segunda bifurcación (en `SmsVerificationScreen`, al recibir `AuthNeedsRegistration`)**: según qué tan completos llegaron los query params, se decide si `RegisterProfileScreen` se abre **bloqueada** (banner de rol, sin campos manuales) o **abierta** (formulario manual, rol fijo en `'client'`) — `_isDriverFullPackage()` / `_isClientFullPackage()` [sms_verification_screen.dart:180-208].
3. **Tercera bifurcación (dentro de `AuthBloc._onRegisterUser`)**: `isDriver` determina si se ejecuta el bloque completo de subida de 6 documentos ([auth_bloc.dart:400-497]) o si se salta directo a crear el perfil.
4. **Cuarta bifurcación (en el redirect, tras `AuthAuthenticated`)**: `isApproved` decide si el conductor ve `DriverApprovalScreen` (bloqueante) o pasa directo a `DriverDashboardScreen`; el cliente nunca pasa por esta bifurcación porque siempre nace con `isApproved:true`.
