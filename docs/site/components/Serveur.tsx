import { PAGE_PAR_ID } from '@/content/pages'
import { Tableau, Videurs, Sondes, Lexique, Dictionnaire, MenuSupabase, Schema, Liste, Decision } from './Composants'

/** LE SERVEUR — la carte (tables, fonctions, règles, edge), les sondes, le lexique, le dictionnaire plié. */
export function Serveur() {
  const p = PAGE_PAR_ID.serveur
  return (
    <section className="page" id="serveur">
      <h1>{p.libelle}</h1>
      <p className="phrase">{p.phrase}</p>
      <MenuSupabase />

      <div className="reveal">
        <h2>Les douze tables</h2>
        <Tableau genre="table" />
      </div>
      <div className="reveal">
        <h2>Les quinze fonctions</h2>
        <Tableau genre="fonction" />
      </div>
      <div className="reveal">
        <h2>Les vingt-six règles que tu peux changer sans nous</h2>
        <p>Change une valeur dans <code>reward_rules</code>, l&apos;app la lit au prochain lancement. Aucune version à sortir.</p>
        <Tableau genre="regle" />
      </div>
      <div className="reveal">
        <h2>Les deux edge functions</h2>
        <Tableau genre="edge" />
      </div>
      <div className="reveal">
        <h2>Les six videurs</h2>
        <p>Chacun empêche exactement un double-paiement. C&apos;est eux, et rien d&apos;autre, qui rendent la file d&apos;attente sûre.</p>
        <Videurs />
      </div>
      <div className="reveal">
        <h2>Ce que la carte raconte</h2>
        <Liste page="serveur" etats={['men', 'loc', 'srv', 'abs']} />
        <Schema id="carte-1-les-douze-tables" legende="Une séance porte des exercices, qui portent des séries. Une séance écrit dans le carnet et donne un sachet ; un sachet ouvert devient une carte." />
      </div>
      <div className="reveal">
        <h2>Les sondes</h2>
        <p>Les seules preuves dures du site : un appel réel, sa réponse lue, et un témoin qui doit échouer.</p>
        <Sondes />
        <Schema id="diag-1-deux-fichiers-decrivent-les" titre="Un nombre est faux à l'écran — dans quel ordre chercher" plie />
      </div>
      <div className="reveal">
        <h2>Le lexique</h2>
        <Lexique />
      </div>
      <div className="reveal">
        <h2>Le dictionnaire</h2>
        <Schema id="schema-1-d-abord-ou-vivent" legende="Dans le téléphone = perdu à la réinstallation · dans Supabase = gardé · bleu = gardé, mais l'app ne le relit jamais." />
        <Dictionnaire />
        <Schema id="schema-2-1-diagramme-conceptuel" titre="Le diagramme conceptuel, avec les colonnes" plie />
        <Decision titre="La règle qui n'a pas de retour arrière">
          <p><b>Un carnet ne se rembobine pas.</b> On n&apos;efface pas une ligne de <code>coin_ledger</code> ; on en écrit une inverse. Le « Down » d&apos;une migration d&apos;argent retire la fonction, jamais les lignes.</p>
        </Decision>
      </div>
    </section>
  )
}
