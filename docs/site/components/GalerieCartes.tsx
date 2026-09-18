import families from '@/content/cartes.json'
import styles from './GalerieCartes.module.css'

const raretes: Record<string, string> = {
  common: 'Commune', rare: 'Rare', epic: 'Épique', legendary: 'Légendaire',
}

export function GalerieCartes() {
  return (
    <section className={styles.galerie} aria-label="Les illustrations retenues des trois familles">
      <h2>Les trois familles retenues</h2>
      <p>Quatorze illustrations publiées, communes à tous les joueurs. Contraste iPhone et shiny animé encore à vérifier.</p>
      {families.map(family => (
        <section key={family.key} data-famille={family.key} className={styles.famille}>
          <h3>{family.name.fr}</h3>
          <p className={styles.signature}><span lang="en">{family.name.en}</span> · {family.signature}</p>
          <div className={styles.grille}>
            {family.cards.map(card => (
              <figure key={card.key} data-carte={card.key}>
                <img src={card.src} width={card.width} height={card.height}
                  alt={`${card.name.fr}, ${raretes[card.rarity]} — ${family.name.fr}`}
                  loading="lazy" decoding="async" />
                <figcaption>
                  <span className={styles.rarete}>{raretes[card.rarity]}</span>
                  <b>{card.name.fr}</b>
                  <span lang="en">{card.name.en}</span>
                </figcaption>
              </figure>
            ))}
          </div>
        </section>
      ))}
    </section>
  )
}
