export const ETATS = ["vide", "active_zero", "active", "seance_debut", "seance", "depart"] as const;
export type Etat = typeof ETATS[number];
export type Variante = { id: string; fragments: string[]; bouton: string | null };
export type Lot = { schema: 1; langue: "fr" | "en"; revision: string; variantes: Record<Etat, Variante[]> };

// Le nombre et les salutations restent des jetons ; aucun profil n'est envoyé au modèle.
export const SCHEMA = {
  type: "object", additionalProperties: false, required: [...ETATS],
  properties: Object.fromEntries(ETATS.map(etat => {
    const champs = etat === "depart" ? ["amorce", "bouton"]
      : ["ligne2", ...(etat === "active" || etat === "seance" ? [] : ["ligne3"]), "ligne4"];
    return [etat, {
    type: "array", minItems: etat === "depart" ? 27 : 3, maxItems: etat === "depart" ? 27 : 3,
    items: {
      type: "object", additionalProperties: false, required: champs,
      properties: Object.fromEntries(champs.map(c => [c, { type: "string", minLength: 1, maxLength: c === "bouton" ? 15 : 24 }])),
    },
  }]; })),
};

/// L'IA écrit uniquement les mots libres. Les emplacements des faits, le prénom
/// et la charnière du pull sont composés ici, pas laissés au modèle.
export function assembler(value: Record<Etat, Record<string, string>[]>, langue: "fr" | "en"): unknown {
  return Object.fromEntries(ETATS.map(etat => [etat, value[etat]?.map((row, i) => ({
    fragments: etat === "depart"
      ? [i === 0 ? "{allez}" : row.amorce, langue === "fr" ? "glisse pour lancer" : "slide to start", langue === "fr" ? "ta séance." : "your session."]
      : [etat.startsWith("seance") ? "{allez}" : "{salut}", row.ligne2,
          etat === "active" ? "{seances}" : etat === "seance" ? "{minutes}" : row.ligne3, row.ligne4],
    bouton: etat === "depart" ? row.bouton : null,
  }))]));
}

export function valider(value: unknown, langue: "fr" | "en", revision: string): Lot {
  if (!value || typeof value !== "object") throw new Error("lot_invalide");
  const input = value as Record<string, unknown>;
  const variantes = {} as Lot["variantes"];
  for (const etat of ETATS) {
    const rows = input[etat];
    if (!Array.isArray(rows) || rows.length !== (etat === "depart" ? 27 : 3)) throw new Error(`nombre_${etat}`);
    const vus = new Set<string>();
    variantes[etat] = rows.map((row, i) => {
      const f = row?.fragments;
      if (!Array.isArray(f) || f.length !== (etat === "depart" ? 3 : 4) ||
          f.some(x => typeof x !== "string" || !x.trim() || x !== x.trim() || x.length > 27 || /[\n\r\d<>]/.test(x))) {
        throw new Error(`fragments_${etat}_${i}`);
      }
      const cle = f.join("|").toLocaleLowerCase(langue);
      // Chaque jeton représente deux mots (salutation + prénom, nombre + unité).
      // La limite éditoriale s'applique aussi aux futures publications.
      const mots = f.join(" ").replace(/\{(?:salut|allez|seances|minutes)\}/g, "mot mot")
        .trim().split(/\s+/).length;
      if (mots > 14) throw new Error(`phrase_longue_${etat}_${i}`);
      if (vus.has(cle)) throw new Error(`doublon_${etat}`);
      vus.add(cle);
      if (etat !== "depart" && f[0] !== (etat.startsWith("seance") ? "{allez}" : "{salut}")) throw new Error(`salut_${etat}`);
      if (etat === "active" && f[2] !== "{seances}") throw new Error("seances_inventees");
      if (etat === "seance" && f[2] !== "{minutes}") throw new Error("minutes_inventees");
      const autorises = new Set(["{salut}", "{allez}", ...(etat === "active" ? ["{seances}"] : []), ...(etat === "seance" ? ["{minutes}"] : [])]);
      for (const x of f) {
        for (const token of x.match(/\{[^}]*\}/g) ?? []) if (!autorises.has(token)) throw new Error("jeton_inconnu");
        if (/[{}]/.test(x.replace(/\{(?:salut|allez|seances|minutes)\}/g, ""))) throw new Error("jeton_incomplet");
      }
      if (etat === "depart") {
        if (!f[0].endsWith(",") && f[0] !== "{allez}") throw new Error("virgule_depart");
        if (f[1] !== (langue === "fr" ? "glisse pour lancer" : "slide to start") ||
            f[2] !== (langue === "fr" ? "ta séance." : "your session.")) throw new Error("langue_depart");
        if (typeof row.bouton !== "string" || !row.bouton.trim() || row.bouton.length > 18 || /[\n\r{}<>\d]/.test(row.bouton)) throw new Error("bouton_invalide");
      } else if (row.bouton !== null) throw new Error("bouton_hors_depart");
      return { id: `${langue}-${etat}-${i + 1}`, fragments: f, bouton: row.bouton };
    });
  }
  return { schema: 1, langue, revision, variantes };
}

export function consigne(langue: "fr" | "en"): string {
  return `Write a complete catalogue for Nosfy, a premium fitness app, in ${langue === "fr" ? "natural French, tutoiement, gender neutral" : "natural English"}.
Short, warm, playful, calm confidence. No guilt, shaming, pain, insults, promises of results or invented facts. No names, numbers, emoji, HTML, headings or medical advice.
For French, the user explicitly wants occasional English touches: at most three depart variants may include flow, reset, Go or Let’s go; at most one Home variant may include flow. Keep the surrounding sentence genuinely French. No systematic anglicisms or gendered/inclusive-dot adjectives.
Exactly 3 variants for each Home state, 27 DIFFERENT variants for depart. Each line <= 24 characters, short enough for a 300pt line of Inter Semibold 30. Buttons <= 15 characters.
Keep every Home to about 8–12 words in total including the greeting and count, never more than 14. One short sentence, not a speech. The pull stays about 6–10 words including its fixed instruction.
You ONLY write the editable fields in the schema. The server adds the greeting as line 1. Do not include greetings, placeholders or any braces in your fields.
vide: first ever workout invitation, no previous workouts implied.
active_zero: no workout this week. No achievements implied.
active: write ligne2 and ligne4 around the server's line 3 which is the true workout count + unit (e.g. '3 séances' / '3 workouts'). Make clear this is this week, not lifetime. Never write line 3 or numbers yourself.
seance_debut: the session has just started, without a count.
seance: write ligne2 and ligne4 around the server's line 3 which is the true duration + unit (e.g. '12 minutes'). No invented effort, performance or intensity. Never write line 3 yourself.
depart: write amorce, a short inviting phrase ending in a comma. It must read naturally with the next two fixed lines: ${langue === "fr" ? '"glisse pour lancer", "ta séance."' : '"slide to start", "your session."'}. Also write a short compatible bouton, in the same language. No unfinished joke whose punchline is missing.
Return the JSON object matching the schema. Distinct variants within each state.`;
}
