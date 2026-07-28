// Woop — synthèse hebdomadaire.
//
// L'app envoie un résumé chiffré de la semaine ; cette fonction appelle Claude
// et renvoie quelques phrases en français. La clé Anthropic ne quitte jamais le
// serveur : c'est toute la raison d'être de cette fonction.
//
// Déploiement :
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy weekly-synthesis

import Anthropic from "npm:@anthropic-ai/sdk@^0.70.0";

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
});

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ExerciseSummary {
  name: string;
  sets?: { reps: number; weight: number }[];
  phases?: { kind: string; seconds: number; speed: number }[];
}

interface WorkoutSummary {
  date: string;
  exercises: ExerciseSummary[];
}

interface Payload {
  period: "week" | "month";
  workouts: WorkoutSummary[];
  /// Mêmes données sur la période précédente, pour que le modèle puisse comparer.
  previous?: WorkoutSummary[];
  weeklyTarget: number;
}

const SYSTEM = `Tu es le coach de Kathryn dans son app de musculation Woop.

Tu reçois ses séances sous forme de données chiffrées. Tu écris une synthèse
courte, en français, qui tient en 4 à 6 phrases.

Comment écrire :
- Commence par le fait le plus marquant de la période, pas par une formule d'accueil.
- Appuie chaque remarque sur un chiffre présent dans les données. N'invente jamais
  une charge, une durée ou une séance qui n'y figure pas.
- Signale une progression réelle quand il y en a une, et une stagnation quand il y
  en a une. Ne force pas l'enthousiasme.
- Termine par une seule recommandation concrète pour la période suivante.
- Tutoie-la. Pas de listes à puces, pas de titres, pas d'emoji. Du texte courant.

Si les données sont trop maigres pour conclure quoi que ce soit, dis-le en une
phrase plutôt que de meubler.`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  // La fonction est protégée par le JWT Supabase : sans utilisateur
  // authentifié, on ne dépense pas de tokens.
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "corps de requête invalide" }, 400);
  }

  if (!payload.workouts?.length) {
    return json({
      synthesis: "Pas encore assez de séances sur la période pour en tirer quelque chose.",
    });
  }

  const prompt = [
    `Objectif hebdomadaire : ${payload.weeklyTarget} séances.`,
    `Période analysée : ${payload.period === "week" ? "la semaine écoulée" : "le mois écoulé"}.`,
    "",
    "Séances de la période :",
    JSON.stringify(payload.workouts, null, 2),
    payload.previous?.length
      ? `\nPériode précédente, pour comparaison :\n${JSON.stringify(payload.previous, null, 2)}`
      : "\nAucune donnée sur la période précédente.",
  ].join("\n");

  try {
    const message = await anthropic.beta.messages.create({
      model: "claude-opus-5",
      max_tokens: 1024,
      // Tâche de synthèse courte : un effort faible suffit et garde la réponse rapide.
      output_config: { effort: "low" },
      // Si les classificateurs déclinent la requête, un modèle de repli répond
      // dans le même appel plutôt que de renvoyer une erreur à l'app.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: SYSTEM,
      messages: [{ role: "user", content: prompt }],
    });

    if (message.stop_reason === "refusal") {
      return json({ error: "La synthèse n'a pas pu être générée." }, 502);
    }

    const text = message.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("\n")
      .trim();

    return json({ synthesis: text, model: message.model });
  } catch (error) {
    console.error("appel Anthropic échoué", error);
    return json({ error: "La synthèse est momentanément indisponible." }, 502);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
