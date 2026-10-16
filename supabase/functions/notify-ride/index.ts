import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Notificación push de un evento de viaje. Seguridad:
// - Exige el JWT de un usuario con sesión (Authorization: Bearer ...).
// - Solo recibe `type` y `ride_id`: todos los textos salen de la base, nunca
//   del cliente.
// - Quien llama debe ser parte del viaje y la contraparte del destinatario
//   (el conductor avisa al pasajero y viceversa).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

type NotificationType =
  | "ride_accepted"
  | "driver_arriving"
  | "driver_arrived"
  | "trip_started"
  | "trip_completed"
  | "ride_cancelled"
  | "new_ride_request"
  | "offer_received"
  | "offer_accepted";

// Avisos que recibe el pasajero (los envía el conductor).
const clientNotifications: NotificationType[] = [
  "ride_accepted", "driver_arriving", "driver_arrived",
  "trip_started", "trip_completed", "offer_received",
];
// Avisos que recibe el conductor (los envía el pasajero).
const driverNotifications: NotificationType[] = [
  "new_ride_request", "offer_accepted", "ride_cancelled",
];

function respond(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function getFCMAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const payload = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  })).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signingInput = `${header}.${payload}`;
  const privateKeyPem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(privateKeyPem), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", cryptoKey,
    new TextEncoder().encode(signingInput)
  );
  const b64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const jwt = `${signingInput}.${b64Signature}`;
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return respond({ error: "No autorizado" }, 401);
    }
    const userJwt = authHeader.replace("Bearer ", "");

    const supabaseAuth = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${userJwt}` } } }
    );
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser();
    if (authError || !user) {
      return respond({ error: "Token inválido" }, 401);
    }
    const callerId = user.id;

    const { type, ride_id }: { type: NotificationType; ride_id: string } = await req.json();
    if (!type || !ride_id) {
      return respond({ error: "type y ride_id son requeridos" }, 400);
    }

    const toClient = clientNotifications.includes(type);
    const toDriver = driverNotifications.includes(type);
    if (!toClient && !toDriver) {
      return respond({ error: "Tipo de notificación inválido" }, 400);
    }

    // Service role: lee perfiles ajenos (el token FCM del destinatario).
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: ride, error: rideError } = await supabase
      .from("rides")
      .select("id, client_id, driver_id, status, origin_name, dest_name, offered_price, final_price")
      .eq("id", ride_id)
      .maybeSingle();
    if (rideError || !ride) {
      return respond({ error: "Viaje no encontrado" }, 404);
    }

    // Quien llama debe ser la contraparte del destinatario en este viaje.
    const senderId = toClient ? ride.driver_id : ride.client_id;
    const recipientId = toClient ? ride.client_id : ride.driver_id;
    if (!senderId || senderId !== callerId) {
      return respond({ error: "Sin permiso para este viaje" }, 403);
    }
    if (!recipientId) {
      return respond({ skipped: true, reason: "Viaje sin destinatario" });
    }

    // Perfiles por separado (sin depender del nombre de las FK de `rides`).
    const participantIds = [ride.client_id, ride.driver_id].filter(Boolean);
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, full_name, fcm_token")
      .in("id", participantIds);
    const byId = new Map((profiles ?? []).map((p: any) => [p.id, p]));
    const clientProfile: any = byId.get(ride.client_id);
    const driverProfile: any = ride.driver_id ? byId.get(ride.driver_id) : null;
    const recipientFcmToken: string | null =
      (toClient ? clientProfile : driverProfile)?.fcm_token ?? null;

    const firstName = (name?: string | null) => name?.trim().split(/\s+/)[0] || null;
    const price = Number(ride.final_price ?? ride.offered_price ?? 0).toFixed(2);
    const driverName = firstName(driverProfile?.full_name) ?? "Tu conductor";
    const clientName = firstName(clientProfile?.full_name) ?? "El pasajero";
    const destName = ride.dest_name ?? "tu destino";
    const originName = ride.origin_name ?? "el origen";

    let title = "";
    let body = "";
    switch (type) {
      case "ride_accepted":
        title = "🚗 ¡Conductor encontrado!";
        body = `${driverName} aceptó tu solicitud. Está en camino.`;
        break;
      case "driver_arriving":
        title = "🚗 Tu conductor está en camino";
        body = `${driverName} se dirige al punto de recojo.`;
        break;
      case "driver_arrived":
        title = "📍 ¡Tu conductor llegó!";
        body = `${driverName} te está esperando.`;
        break;
      case "trip_started":
        title = "🛣️ Viaje iniciado";
        body = `Tu viaje a ${destName} ha comenzado.`;
        break;
      case "trip_completed":
        title = "✅ Viaje completado";
        body = `Llegaste a ${destName}. ¡Gracias por usar Lleva!`;
        break;
      case "ride_cancelled":
        title = "❌ Viaje cancelado";
        body = "El pasajero canceló el viaje.";
        break;
      case "new_ride_request":
        title = "🔔 Nueva solicitud";
        body = `${originName} → ${destName} · S/ ${price}`;
        break;
      case "offer_received":
        title = "💰 Nueva contraoferta";
        body = `El conductor propone S/ ${price} por tu viaje.`;
        break;
      case "offer_accepted":
        title = "✅ ¡Oferta aceptada!";
        body = `${clientName} aceptó tu oferta de S/ ${price}.`;
        break;
    }

    if (!recipientFcmToken) {
      return respond({ skipped: true, reason: "Sin token FCM" });
    }

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      return respond({ error: "Firebase no configurado" }, 500);
    }
    const serviceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getFCMAccessToken(serviceAccount);

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: recipientFcmToken,
            notification: { title, body },
            data: { type, ride_id },
            android: {
              priority: "high",
              notification: {
                // Debe coincidir con NotificationService.channelId en la app.
                channel_id: "lleva_default_channel",
                priority: "max",
                default_sound: true,
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: { title, body },
                  sound: "default",
                  badge: 1,
                },
              },
            },
          },
        }),
      }
    );

    if (!fcmResponse.ok) {
      console.error("FCM error:", await fcmResponse.text());
    }
    return respond({ success: fcmResponse.ok });
  } catch (error) {
    console.error("Error:", error);
    return respond({ error: "Error interno" }, 500);
  }
});
