# -*- coding: utf-8 -*-
"""
LE CATALOGUE DES EXERCICES → SQL (13-09).

Le catalogue vit dans Nosfy/Models.swift (`ExerciseCatalog.all`) et nulle part
ailleurs. Le serveur en a besoin pour NOMMER ce qu'il compte (widget_volume,
widget_peak, profil().exercices) : ce script lit le Swift et écrit une
migration qui pose (ou remet à jour) la table `exercices`, ligne par ligne,
idempotente (insert … on conflict do update).

    python3 tools/widgets/catalogue_sql.py supabase/migrations/<horodatage>_catalogue_exercices.sql

⚠️ Une migration DÉPLOYÉE ne se réécrit pas : un exercice ajouté dans le
Swift = une NOUVELLE migration générée par ce script (l'upsert ne touche
que ce qui change). L'écran ne lit jamais cette table : le catalogue Swift
reste la source ; la table est le miroir que le serveur lit.
"""
import re, sys, datetime

RACINE = __file__.rsplit("/tools/", 1)[0]
swift = open(RACINE + "/Nosfy/Models.swift", encoding="utf-8").read()
pat = re.compile(r'Exercise\(\s*id: "([^"]+)", name: "([^"]+)",\s*category: \.(\w+), equipment: \.(\w+), tracking: \.(\w+),\s*muscle: "([^"]*)",\s*cue: "([^"]*)",\s*mistake: "([^"]*)"\s*\)', re.S)
rows = pat.findall(swift)
if not rows:
    sys.exit("aucun exercice lu dans Models.swift — le format a changé ?")

CATEGORIE = {"haut": "Haut", "abdos": "Abdos", "bas": "Bas", "fessiers": "Fessiers", "cardio": "Cardio"}
def q(s): return "'" + s.replace("'", "''") + "'"

out = sys.argv[1] if len(sys.argv) > 1 else None
lignes = []
lignes.append("-- ════════════════════════════════════════════════════════════════════════")
lignes.append("-- LE CATALOGUE DES EXERCICES, AU SERVEUR — généré par tools/widgets/catalogue_sql.py")
lignes.append(f"-- depuis Nosfy/Models.swift (ExerciseCatalog.all), le {datetime.date.today().isoformat()} : {len(rows)} exercices.")
lignes.append("--")
lignes.append("-- Le catalogue Swift reste LA source (l'écran ne lit jamais cette table) ;")
lignes.append("-- la table est le miroir que le serveur lit pour NOMMER ce qu'il compte :")
lignes.append("-- widget_volume / widget_peak (nom, catégorie), profil().exercices.")
lignes.append("-- Un exercice ajouté dans le Swift = une nouvelle migration générée par le script.")
lignes.append("-- ════════════════════════════════════════════════════════════════════════")
lignes.append("")
lignes.append("""create table if not exists public.exercices (
  id          text primary key,            -- l'id du catalogue Swift (ex. hip-thrust)
  nom         text not null,
  categorie   text not null,               -- Haut · Abdos · Bas · Fessiers · Cardio (ExerciseCategory.rawValue)
  equipement  text not null,               -- barre · halteres · machine · poidsDuCorps · poulie
  tracking    text not null,               -- setsRepsWeight · intervals · steady
  muscle      text not null,
  consigne    text not null,
  erreur      text not null,
  updated_at  timestamptz not null default now()
);
alter table public.exercices enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'exercices' and policyname = 'lecture') then
    create policy "lecture" on public.exercices for select to authenticated using (true);
  end if;
end $$;
grant select on public.exercices to authenticated;
comment on table public.exercices is 'Le miroir du catalogue Swift (ExerciseCatalog.all), écrit par migration seulement (tools/widgets/catalogue_sql.py). Lu par widget_volume, widget_peak, profil() pour nommer les exercices. Aucune écriture depuis l''app.';
""")
lignes.append("insert into public.exercices (id, nom, categorie, equipement, tracking, muscle, consigne, erreur) values")
vals = []
for (id_, nom, cat, equip, track, muscle, cue, mistake) in rows:
    vals.append(f"  ({q(id_)}, {q(nom)}, {q(CATEGORIE[cat])}, {q(equip)}, {q(track)}, {q(muscle)}, {q(cue)}, {q(mistake)})")
lignes.append(",\n".join(vals))
lignes.append("""on conflict (id) do update set
  nom = excluded.nom, categorie = excluded.categorie, equipement = excluded.equipement,
  tracking = excluded.tracking, muscle = excluded.muscle, consigne = excluded.consigne,
  erreur = excluded.erreur, updated_at = now();
""")
sql = "\n".join(lignes)
if out:
    open(out, "w", encoding="utf-8").write(sql)
    print(f"{len(rows)} exercices → {out}")
else:
    print(sql)
