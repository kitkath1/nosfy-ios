import SwiftUI

// MARK: - flamme-jauge

/// La carte « Séries » au feu : le médaillon-bijou laqué à gauche (le shader
/// `jaugeLacque`, la recette du galet play transposée à l'orange), le compte
/// au centre, les cinq petites flammes qui dansent, et la jauge-braise
/// saupoudrée de diamants. Tout est HARD-CODÉ : cinq séries, une palette,
/// pas un seul paramètre de thème — c'est un bijou autonome.
///
/// La leçon anti-brun s'applique partout : sur toute la rampe orange, la
/// SATURATION reste haute. Un orange qui perd sa saturation en s'assombrissant
/// devient marron ; ici la rampe descend en TEINTE (or → orange → braise
/// rouge), jamais en saturation.
///
/// LE DÉPLIEMENT (15-08) : la carte sait désormais S'OUVRIR — `ouverture`
/// (0 bijou fermé → 1 carte plein écran) fait grossir le médaillon qui
/// s'embrase, arrondit les coins au rayon des grandes cartes, et révèle
/// `detail` (la liste des séries, chez la fiche exo) sous l'en-tête, dans
/// la même coque. À 0, rien ne change : le bijou du banc est intact.
struct FlammeJauge<Detail: View>: View {
    /// Le défilement de la liste des séries — il ne sert qu'à faire venir
    /// la matière sous l'en-tête quand on descend.
    @State private var defile: CGFloat = 0

    /// Séries validées. La jauge, le compte et les petites flammes
    /// suivent tous cette seule valeur.
    var done: Int

    /// LE TOTAL RÉEL des séries (16-08). Il valait 5 en dur : la carte ne
    /// pouvait donc pas savoir qu'il y en avait dix, et la rangée
    /// affichait cinq flammes quoi qu'il arrive. L'hôte le passe
    /// désormais ; 5 reste le repli du banc.
    var total: Int = 5

    /// LA LIGNE DE CONTRAT sous le compte — « 5 séries · 12 reps · 20 kg ».
    /// Elle remplace « Touchez pour voir le détail » (16-08) et reste
    /// visible carte dépliée. L'hôte la compose : lui seul connaît les
    /// répétitions et les charges.
    var contrat: String = ""

    /// Le dépliement [0,1] — piloté par le scroll de la fiche exo. La
    /// coque est une fonction pure de lui : remonter rembobine.
    var ouverture: CGFloat = 0

    /// L'air ajouté EN TÊTE quand la carte embarque le header de la
    /// fiche : l'en-tête flamme vient se poser sous la ligne du chevron.
    var garde: CGFloat = 0

    /// LA CARTE EST EN COURSE (dépliement sous le doigt ou ressort).
    /// Le bijou allège alors sa parure : ses bruits tombent à 30 img/s
    /// (leur frémissement est invisible sur une carte qui bouge) et les
    /// deux couches les plus chères — le GRAIN tuilé et la VEINE d'or en
    /// dégradé angulaire, toutes deux en mode de fusion sur toute la
    /// surface — s'éteignent. Un mouvement n'a pas besoin de détail, il a
    /// besoin d'images.
    var bouge: Bool = false

    /// LA DALLE EST POSÉE DANS UN ÉCRIN (l'aurora de la fiche exo) : ses
    /// coins rentrent d'un liseré pour rester concentriques à la coque
    /// qui l'entoure, et sa VEINE d'or s'éteint — un arc de lumière qui
    /// court sur la tranche, cerné par une lumière vivante, ce serait
    /// deux bijoux qui se disputent le même bord.
    var dansEcrin: Bool = false

    /// LE BANDEAU DE LUMIÈRE en tête, quand la dalle est dans un écrin :
    /// sa hauteur. Le composant n'y dessine rien d'opaque — l'aurora de
    /// l'hôte y passe — mais il y POSE la poignée et les cinq flammes, en
    /// encre sombre (la loi du dessin sombre sur la lumière). C'est ce
    /// qui libère la ligne du titre et rend la carte plus compacte.
    var bandeau: CGFloat = 0
    /// Le liseré d'aurora qui cerne la dalle (côtés et bas).
    var liseré: CGFloat = 0

    /// Ce qui vit dans la carte ouverte, sous l'en-tête. Le composant ne
    /// sait rien de son contenu : il l'héberge dans sa coque et le clippe.
    @ViewBuilder var detail: () -> Detail

    /// Cinq séries, gravées dans le marbre.

    /// LA PARTITION. Une série validée n'est pas un changement d'état, c'est
    /// un accord : le trait part tout de suite (t0), la flamme naît et le
    /// compte roule sur le deuxième temps (+0,16 s), la veine du cadre et
    /// l'inspiration du médaillon suivent avec leurs propres retards. Tout
    /// se lit dans des horodatages — les courbes se calculent au temps, pas
    /// à l'état, comme partout dans l'app.
    @State private var shownDone = 1
    @State private var surgeFrom = 0
    @State private var surgeAt: Date?
    @State private var igniteAt: Date?
    @State private var celebrateAt: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: bouge ? 1.0 / 30.0 : nil)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 3600))
            content(t: t, date: context.date)
        }
        .onAppear { shownDone = done }
        .onChange(of: done) { old, new in
            if new > old {
                surgeFrom = old
                surgeAt = .now
                celebrateAt = .now
                igniteAt = .now.addingTimeInterval(0.16)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        shownDone = new
                    }
                }
            } else {
                // Le retour (5 → 1 en boucle) n'est pas une victoire : pas de
                // cérémonie, juste le ressort qui remet tout en place.
                surgeFrom = new
                surgeAt = nil
                igniteAt = nil
                celebrateAt = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    shownDone = new
                }
            }
        }
    }

    private static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    private func content(t: Float, date: Date) -> some View {
        let o = Double(min(max(ouverture, 0), 1))
        // L'ESSOR DU MÉDAILLON : il grossit À PEINE (×1,25 — « je veux
        // pas que la flamme soit aussi grosse », 15-08) et S'OUVRE : le
        // trait s'affine, la niche s'efface, la danse s'amplifie — tout
        // vit dans le médaillon, porté par `essor`.
        let essor = Self.sstep(0.06, 0.92, o)
        // La taille ne grossit plus à l'ouverture : le bijou est le
        // MÊME dans les deux états, c'est sa demande.
        let taille: CGFloat = 1
        // Les coins : bijou 26 fermé → la coque du profil ouverte (55 en
        // haut, concentrique au châssis derrière le liseré de 5 pt ; 44
        // en bas). Dans l'écrin, on rentre d'un liseré en bas (la
        // concentricité vraie) ; en haut la dalle ne touche pas la coque
        // — la bande d'aurora l'en sépare — donc son rayon n'a qu'à bien
        // lire sous la lumière.
        let rHaut = dansEcrin ? 18 + (26 - 18) * CGFloat(o)
                              : 26 + (55 - 26) * CGFloat(o)
        // Le bas de la dalle est concentrique à l'écrin, rentré d'un
        // liseré (30 - 1 ouvert).
        let rBas = dansEcrin ? 19 + (29 - 19) * CGFloat(o)
                             : 26 + (44 - 26) * CGFloat(o)
        let coque = UnevenRoundedRectangle(
            topLeadingRadius: rHaut, bottomLeadingRadius: rBas,
            bottomTrailingRadius: rBas, topTrailingRadius: rHaut,
            style: .continuous)
        // LA DALLE RESPIRE (« les textes trop collés en haut et en bas »,
        // 15-08) : l'air intérieur remonte à 17 pt. Le plancher reste le
        // MÉDAILLON (58 pt) — mais ce n'est plus lui qui décide : la
        // dalle vit maintenant au-dessus de son minimum, et c'est ce vide
        // autour du texte qui la rend calme.
        // 17 → 13 fermé (16-08, Phase 1 restauration : la carte de la
        // référence fait ~127 pt — le bandeau a rendu 6 pt chez l'hôte,
        // padV rend les 8 autres). Ouvert : 20, comme avant.
        let padV = 11 + 9 * CGFloat(o)
        let padG = 14 + 2 * CGFloat(o)
        let padD = 16 + 2 * CGFloat(o)
        return VStack(spacing: 0) {
            // LE BANDEAU DE LUMIÈRE : rien d'opaque — l'aurora de l'hôte
            // le traverse — mais il porte la poignée (« tire-moi », la
            // grammaire du profil) et les cinq flammes, montées ici pour
            // dégager la ligne du titre. Aligné en BAS : ouvert, le
            // bandeau devient tout le haut de l'écran et son contenu doit
            // rester au bord de la dalle, pas flotter sous le chevron.
            if bandeau > 0 {
                bandeauEcrin(o: o)
                    .frame(height: bandeau, alignment: .bottom)
            }
            dalle(t: t, date: date, o: o, essor: essor, taille: taille,
                  coque: coque, padV: padV, padG: padG, padD: padD)
                .padding(.horizontal, liseré)
                .padding(.bottom, liseré)
        }
        .frame(maxWidth: .infinity,
               maxHeight: o > 0.001 ? .infinity : nil,
               alignment: .top)
    }

    /// Le contenu du bandeau, en encre sombre — la seule qui existe sur
    /// la lumière. La POIGNÉE au centre (l'affordance du « tire-moi »),
    /// et à gauche l'inscription MINIMALE : un point, un mot. Elle
    /// s'efface dès les premiers centimètres de la course — un titre n'a
    /// rien à faire sur une carte qui s'ouvre, le contenu parle.
    /// (Les flammes y sont passées un instant : elles sont retournées
    /// dans la dalle, c'est leur place.)
    private func bandeauEcrin(o: Double) -> some View {
        let vie = 1 - Self.sstep(0.02, 0.30, o)
        // LE BANDEAU EST SOMBRE LUI AUSSI (15-08) : toute la carte est
        // d'un seul verre fumé, la lumière ne vit qu'à l'intérieur. Donc
        // l'encre redevient BLANCHE — et le point, lui, passe à l'ORANGE
        // (la référence de Kathryn : une pastille de braise à côté du
        // mot).
        return ZStack {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 34, height: 4)
            HStack(spacing: 7) {
                Circle()
                    .fill(FlammePalette.flamme)
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: FlammePalette.coeur.opacity(0.55),
                            radius: 2.5)
                // BEIGE DORÉ, pas blanc (le microscope du 16-08 : la
                // référence encre « Training » à ~(0,78 ; 0,70 ; 0,53)).
                Text("Training")
                    .font(.inter(11, .medium))
                    .tracking(0.3)
                    .foregroundStyle(Color(red: 0.78, green: 0.70, blue: 0.53))
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            .opacity(vie)
            .padding(.leading, 14 + liseré)
        }
        .frame(height: 20)
        .padding(.bottom, 9)
    }

    /// LA DALLE — la carte noire elle-même, telle qu'elle a toujours été.
    private func dalle(t: Float, date: Date, o: Double, essor: Double,
                       taille: CGFloat, coque: UnevenRoundedRectangle,
                       padV: CGFloat, padG: CGFloat,
                       padD: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14 + 8 * CGFloat(essor)) {
                FlammeMedaillon(t: t, date: date, celebrateAt: celebrateAt,
                                essor: essor, calme: bouge)
                    // L'INSPIRATION DU DÉPLIEMENT (16-08) : le bijou prend
                    // son souffle pendant la course — il enfle de 6 % et
                    // son aura monte, puis tout retombe. `sin(essor·π)`
                    // vaut ZÉRO aux deux bouts : le médaillon au repos est
                    // au pixel le même, fermé comme ouvert (sa loi).
                    .scaleEffect(1 + 0.06 * sin(min(max(essor, 0), 1) * .pi))
                    .shadow(color: FlammePalette.coeur
                                .opacity(0.55 * sin(min(max(essor, 0), 1) * .pi)),
                            radius: 14)
                    // Le scale rend TOUT plus grand (lueurs et ombres
                    // comprises) ; le frame donne la place — la ligne
                    // s'écarte, rien ne se chevauche.
                    .scaleEffect(taille)
                    .frame(width: 58 * taille, height: 58 * taille)
                // 10 → 15 : la jauge ne colle plus au sous-titre.
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            titre
                            // L'invite meurt avec l'ouverture : le détail
                            // est LÀ — et l'espace pris par le médaillon
                            // la tronquerait de toute façon.
                            // 16-08 : « le texte "Touchez pour voir le
                            // détail" est nul, mets un truc en rapport
                            // avec les séries, et garde-le quand c'est
                            // déplié ». Le contrat de la séance, vrai à
                            // tout instant et sans calcul d'état — et il
                            // ne s'efface PLUS à l'ouverture.
                            // TAILLE FIXE (16-08) : « la taille du texte
                            // bouge quand on passe de la mini carte à la
                            // grande ». C'était `minimumScaleFactor` —
                            // la place disponible change au dépliement,
                            // donc SwiftUI rétrécissait le texte dans la
                            // carte fermée puis le rendait à sa taille
                            // pleine dans l'ouverte. La ligne est courte,
                            // elle tient dans les deux : plus de mise à
                            // l'échelle, plus de resserrement.
                            Text(contrat)
                                .font(.inter(12, .regular))
                                .foregroundStyle(Color.white.opacity(0.48))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        Spacer(minLength: 6)
                        // Les cinq flammes vivent ICI, dans la dalle
                        // noire — elles sont montées un instant dans le
                        // bandeau le 15-08, Kathryn les a fait revenir.
                        FlammesRow(done: shownDone, total: total, t: t,
                                   date: date, igniteAt: igniteAt)
                    }
                    JaugeBraise(done: done, total: total, t: t, date: date,
                                surgeAt: surgeAt, surgeFrom: surgeFrom,
                                essor: essor)
                        // 16-08 : « rajoute un espace de 7 px entre la
                        // barre de progression et le bas, sans toucher au
                        // design ». Il vit ICI, sous la jauge, et non dans
                        // le `padV` de la dalle : le padV s'applique aussi
                        // EN HAUT et déplacerait tout le contenu.
                        // Conséquence assumée : la carte fermée passe de
                        // 125 à 132 pt de haut. Les lumières ancrées au
                        // BAS (la braise, son cheveu oblique) suivent
                        // l'arête et ne bougent pas ; celles ancrées au
                        // HAUT non plus. C'est la comparaison à la photo
                        // de référence (125 pt) qui se décale de 7 pt.
                        .padding(.bottom, 7)
                }
            }
            // Le contenu de la carte ouverte, sous l'en-tête — clippé par
            // la coque pendant la croissance (les lignes naissent dedans).
            // FERMÉE, il n'a AUCUNE place : invisible ne suffit pas, une
            // opacité nulle garde sa hauteur et gonflerait le bijou.
            // Il reste MONTÉ (hauteur nulle) — on ne monte rien en plein
            // geste, la saccade a déjà été payée ailleurs.
            // EN OVERLAY sur une plaque claire (15-08, tour 3 du verre) :
            // posé DANS le layout, ses lignes gelées à 358 pt débordaient
            // la proposition — et le `.frame(width:)` de l'hôte CENTRE
            // l'enfant trop grand : la carte fermée s'étalait à 390 pt au
            // lieu de 362 (mesuré au gradient, encarts 6 pt au lieu de
            // 20). Un overlay ne pèse rien dans la mesure ; pendant la
            // croissance le surplus est rogné par l'écrin, sous une
            // opacité encore basse.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: o > 0.001 ? nil : 0, alignment: .top)
                .overlay(alignment: .topLeading) {
                    // LE SCROLL DES SÉRIES (16-08) : « si on fait plus de
                    // 10 séries il faut pouvoir scroller dans la grande
                    // carte ». Jusqu'ici la liste était posée à hauteur
                    // fixe : au-delà de ce que la carte affiche, les
                    // lignes débordaient sans être atteignables.
                    // L'en-tête (médaillon, compte, contrat, flammes,
                    // jauge) est DÉJÀ hors du scroll — il est collant
                    // gratuitement. Ce qui manquait, c'est le scroll et
                    // la jonction entre les deux.
                    ScrollView(.vertical, showsIndicators: false) {
                        detail()
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                    }
                    // LA HAUTEUR DISPONIBLE, ET PAS PLUS : sans cette
                    // borne, la liste prend la hauteur de son CONTENU, le
                    // surplus est simplement rogné par l'écrin, et il n'y
                    // a rien à faire défiler — c'est ce qui donnait « je
                    // vois 7 séries et je n'arrive pas à scroller ».
                    .frame(maxHeight: .infinity, alignment: .top)
                    // `-scrollBas` (banc) : la liste s'ouvre ancrée en BAS.
                    // C'est le test qui prouve qu'elle DÉFILE — si la
                    // dernière série s'affiche, c'est que le contenu est
                    // plus haut que le cadre. Impossible de piloter un
                    // vrai glissement depuis le simulateur en ligne de
                    // commande, donc on prouve autrement.
                    .defaultScrollAnchor(
                        CommandLine.arguments.contains("-scrollBas")
                            ? .bottom : .top)
                    // PAS DE SCROLL PENDANT LA COURSE : la carte s'ouvre
                    // avec son propre geste, et « un scroll ne peut pas
                    // TENIR une carte » (la leçon de la carte des séries).
                    // Tant qu'elle n'est pas posée, le doigt appartient
                    // au dépliement.
                    // Seuil ASSOUPLI : la carte s'ouvre à la main et son
                    // ressort ne se pose pas toujours pile à 1,000 — à
                    // 0,995 le scroll restait mort. Et `bouge` est retiré
                    // de la condition : son extinction dépend d'un jeton
                    // qui peut survivre au geste, ce qui gelait le scroll
                    // pour de bon.
                    .scrollDisabled(o < 0.90)
                    // LE FONDU DU HAUT : les lignes ne se coupent pas net
                    // sous l'en-tête, elles s'y effacent sur 16 pt.
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white, location: 0.035),
                                .init(color: .white, location: 1.0),
                            ],
                            startPoint: .top, endPoint: .bottom)
                    }
                    // LA MATIÈRE, sous l'en-tête : invisible en haut de
                    // liste, elle vient au fur et à mesure du défilement
                    // (pleine force à 20 pt). Deux flous empilés coûtent
                    // cher — celui-ci n'existe donc QUE quand il sert.
                    .overlay(alignment: .top) {
                        // 16-08 : « il y a une sorte de trait gris qui est
                        // apparu quand j'ai scrollé ». C'était CETTE bande.
                        // Un `ultraThinMaterial` sur un fond noir ne floute
                        // pas : il POSE UN VOILE GRIS, et sur une carte
                        // aussi sombre le voile est plus visible que ce
                        // qu'il cache. La matière reste — pour le verre —
                        // mais au tiers de sa force, et c'est un dégradé
                        // NOIR qui fait le travail d'effacement : il rend
                        // la carte à sa propre couleur au lieu de la
                        // grisailler. Hauteur portée de 14 à 26 pt pour que
                        // la transition n'ait aucun bord.
                        ZStack(alignment: .top) {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.32)
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.55), location: 0.0),
                                    .init(color: .black.opacity(0.30), location: 0.45),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .top, endPoint: .bottom)
                        }
                        .frame(height: 26)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0.55), location: 0.5),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .top, endPoint: .bottom)
                        }
                        .opacity(bouge ? 0 : min(1, max(0, defile / 24)))
                        .allowsHitTesting(false)
                    }
                    .onScrollGeometryChange(for: CGFloat.self) {
                        $0.contentOffset.y
                    } action: { _, v in
                        // UNE SEULE sonde par scroll, et sur un champ
                        // VIVANT : une sonde qui renvoie une constante
                        // n'est jamais rappelée (leçon payée ailleurs).
                        if abs(v - defile) > 0.5 { defile = v }
                    }
                }
        }
        .padding(.leading, padG)
        .padding(.trailing, padD)
        .padding(.vertical, padV)
        // La garde : l'air du header embarqué — l'en-tête descend sous
        // la ligne du chevron quand la carte prend l'écran (morte quand
        // c'est le bandeau qui écarte).
        .padding(.top, garde)
        // Fermée : la taille naturelle du bijou. En ouverture : l'hôte
        // impose le cadre, l'en-tête reste en tête.
        .frame(maxWidth: .infinity,
               maxHeight: o > 0.001 ? .infinity : nil,
               alignment: .topLeading)
        .background(carte(t: t, date: date, coque: coque))
        // Les lueurs vivent DANS le bijou : sans ce clip, l'ombre portée de
        // la braise fuyait sous la carte en une bande dorée.
        .clipShape(coque)
    }

    /// Le titre — en DÉGRADÉ (verdict du 15-08) : blanc en tête, gris au
    /// pied. C'est la matière des titres de la maison (l'école du
    /// `titleFade` de la home) : une lettre pleinement blanche est plate,
    /// une lettre qui s'éteint vers le bas a du relief.
    /// (Vit dans `FlammePalette` : `FlammeJauge` est un type GÉNÉRIQUE
    /// depuis qu'il héberge son contenu, et Swift interdit les propriétés
    /// statiques stockées dans un générique — l'erreur qui a fait échouer
    /// deux builds le 15-08.)
    private var titre: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("Sets")
                .font(.inter(18, .semibold))
            // 16-08 : « on ne met pas 3/5, on met juste 3, que ce soit 3
            // ou 10 ». Le total vit déjà dans la rangée de flammes.
            Text("\(shownDone)")
                .font(.inter(19, .bold))
                .contentTransition(.numericText(value: Double(shownDone)))
        }
        .foregroundStyle(FlammePalette.encreTitre)
        .lineLimit(1)
        .fixedSize()
    }

    /// La plaque : un gradient vertical sombre, du GRAIN pour la matière
    /// mate, une vignette qui assoit le contenu, le sertissage — et la VEINE :
    /// un court arc de lumière qui circule sur la tranche, cadencé par le
    /// bruit, et qui fait un tour rapide quand une série se valide.
    private func carte(t: Float, date: Date,
                       coque: UnevenRoundedRectangle) -> some View {
        let souffle = 0.72 + 0.28 * Double(JaugeVent.souffle(t))
        // La veine : sa position du moment, et sa célébration éventuelle.
        let lent = Double(t) * 0.048
        var angle = (lent - floor(lent)) * 360.0
        var veineOp = 0.30 + 0.18 * Double(JaugeVent.souffle(t))
        if let c = celebrateAt {
            let e = date.timeIntervalSince(c) - 0.25
            if e > 0, e < 0.9 {
                let q = e / 0.9
                angle += (1 - pow(1 - q, 3)) * 360
                veineOp += sin(.pi * q) * 0.55
            }
        }
        let veineAngle = angle

        // DANS L'ÉCRIN, LA DALLE N'EXISTE PLUS (la référence du 15-08) :
        // le médaillon, le titre et la jauge sont posés DIRECTEMENT sur
        // le verre de la carte — aucune sous-carte, aucun sertissage.
        // Seule la nappe chaude du médaillon survit : c'est de la
        // lumière, pas une boîte. Hors écrin (le banc -jaugeLab), le
        // bijou garde sa plaque noire d'origine.
        return coque
            .fill(dansEcrin
                  ? LinearGradient(colors: [.clear, .clear],
                                   startPoint: .top, endPoint: .bottom)
                  : LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.102, green: 0.098, blue: 0.106), location: 0.0),
                            .init(color: Color(red: 0.071, green: 0.067, blue: 0.075), location: 0.55),
                            .init(color: Color(red: 0.051, green: 0.047, blue: 0.055), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom))
            .overlay {
                // La lumière de la flamme se couche sur la plaque : une nappe
                // chaude ancrée sur le médaillon, qui respire avec lui.
                // DANS L'ÉCRIN (restauration 16-08) : elle est REVENUE, mais
                // RAS DU MÉDAILLON — la référence la montre (le verre autour
                // du disque tient à ~0,2 de médiane, la lumière de la flamme
                // diffuse dans l'épaisseur) ; sa version large peignait tout
                // le corps, celle-ci meurt à 0,34 de rayon.
                EllipticalGradient(
                    stops: [
                        .init(color: FlammePalette.coeur.opacity((dansEcrin ? 0.21 : 0.10) * souffle), location: 0.0),
                        .init(color: FlammePalette.braise.opacity((dansEcrin ? 0.09 : 0.045) * souffle), location: 0.45),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: UnitPoint(x: 0.115, y: 0.5),
                    startRadiusFraction: 0,
                    endRadiusFraction: dansEcrin ? 0.50 : 0.62)
                .blendMode(.plusLighter)
            }
            .overlay {
                // Le grain : 2-3 %, invisible en tant que tel — mais sans lui
                // l'aplat dégradé se lit « rendu logiciel », pas « matière ».
                // Éteint EN COURSE : une tuile de 96 px fondue en `overlay`
                // sur presque tout l'écran, redessinée à chaque image, est
                // la couche la plus chère de la carte — et la moins
                // regardée quand elle bouge.
                // (Grain, vignette et sertissage MEURENT dans l'écrin —
                // la dalle n'existe plus, on ne dessine pas la boîte
                // d'une chose invisible.)
                if !bouge, !dansEcrin {
                    GrainTexture.tuile
                        .resizable(resizingMode: .tile)
                        .opacity(0.045)
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                // La vignette : les coins s'éteignent, le contenu s'assoit.
                if !dansEcrin {
                    EllipticalGradient(
                        stops: [
                            .init(color: .clear, location: 0.60),
                            .init(color: Color.black.opacity(0.15), location: 1.0),
                        ],
                        center: .center,
                        startRadiusFraction: 0, endRadiusFraction: 0.82)
                }
            }
            .overlay {
                // Le sertissage : la tranche prend la lumière en haut.
                if !dansEcrin {
                    coque
                        .strokeBorder(LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.4),
                                .init(color: Color.white.opacity(0.02), location: 1.0),
                            ],
                            startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
            }
            .overlay {
                // LA VEINE : l'arc d'or qui vit sur la tranche. Longues
                // queues de fondu — dans les coins d'un rectangle arrondi la
                // vitesse angulaire varie, et un arc court y sauterait.
                // Éteinte EN COURSE : un dégradé angulaire recalculé sur
                // tout le contour, en `plusLighter`, à chaque image.
                // Éteinte DANS L'ÉCRIN : la lumière qui entoure la dalle
                // tient déjà ce rôle.
                if !bouge, !dansEcrin {
                    coque
                        .strokeBorder(AngularGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.36),
                                .init(color: FlammePalette.or.opacity(0.25), location: 0.46),
                                .init(color: FlammePalette.blanc.opacity(0.85), location: 0.50),
                                .init(color: FlammePalette.or.opacity(0.25), location: 0.54),
                                .init(color: .clear, location: 0.64),
                                .init(color: .clear, location: 1.0),
                            ],
                            center: .center, angle: .degrees(veineAngle)),
                            lineWidth: 1)
                        .blendMode(.plusLighter)
                        .opacity(veineOp)
                }
            }
            .clipShape(coque)
    }
}

/// Le bijou nu du banc et des appels historiques : fermé, sans contenu.
extension FlammeJauge where Detail == EmptyView {
    init(done: Int, ouverture: CGFloat = 0) {
        self.init(done: done, ouverture: ouverture,
                  detail: { EmptyView() })
    }
}

// MARK: - Palette

/// La rampe de feu, du blanc-chaud à la braise rouge. Quatre arrêts qui ne
/// perdent JAMAIS leur saturation en descendant — c'est la recette anti-brun.
enum FlammePalette {
    /// Blanc chauffé, le cœur le plus vif.
    static let blanc = Color(red: 1.0, green: 0.94, blue: 0.80)
    /// Or de néon.
    static let or = Color(red: 1.0, green: 0.78, blue: 0.38)
    /// Orange plein, le corps du néon.
    static let flamme = Color(red: 1.0, green: 0.55, blue: 0.10)
    /// Cœur orange soutenu.
    static let coeur = Color(red: 1.0, green: 0.40, blue: 0.04)
    /// Braise rouge, le bas de la rampe.
    static let braise = Color(red: 1.0, green: 0.22, blue: 0.02)
    /// Le JAUNE de pointe — celui qui monte en tête de l'onde.
    static let jaune = Color(red: 1.0, green: 0.87, blue: 0.30)

    /// L'encre du titre — blanc en tête, gris au pied : une lettre
    /// pleinement blanche est plate, une lettre qui s'éteint vers le bas
    /// a du relief (l'école du `titleFade` de la home).
    static let encreTitre = LinearGradient(
        stops: [
            .init(color: Color.white, location: 0.0),
            .init(color: Color.white.opacity(0.97), location: 0.42),
            .init(color: Color(white: 0.62), location: 1.0),
        ],
        startPoint: .top, endPoint: .bottom)
    /// L'ENCRE — ce qui s'écrit SUR la lumière (le bandeau d'aurora).
    /// Sur un cœur de lumière, le blanc n'existe pas et l'orange se
    /// délave : seul un brun très sombre et SATURÉ tient (anti-marron).
    static let encre = Color(red: 0.18, green: 0.10, blue: 0.04)

    /// La rampe verticale du néon : or en tête, braise au pied.
    static let neon = LinearGradient(
        stops: [
            .init(color: or, location: 0.0),
            .init(color: flamme, location: 0.45),
            .init(color: coeur, location: 0.78),
            .init(color: braise, location: 1.0),
        ],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Le liseré du médaillon

/// LE LISERÉ BLANC DE LA MAISON — celui des boutons play/pause du player,
/// désormais partagé au lieu d'être recopié : les mêmes crans, les mêmes
/// angles, la même bague. Deux tables de valeurs qui divergent d'un pouième
/// donnent deux matières différentes à l'œil, et c'est exactement ce que
/// Kathryn attrape (« le même liseré blanc joli et l'ombre »).
///
/// Les deux tables sont des `AngularGradient` : elles valent pour un
/// `Circle` comme pour une `Capsule` — l'angle 0 est à 3 h, il tourne dans
/// le sens des aiguilles.
enum LisereMedaillon {
    /// Les CRANS : l'arc vif au sud-ouest, le flare du nord-ouest, les
    /// éteintes entre — jamais un périmètre iso-brillant.
    static let crans: [Gradient.Stop] = [
        .init(color: Color.white.opacity(0.10), location: 0.000),
        .init(color: Color.white.opacity(0.46), location: 0.098),
        .init(color: Color.white.opacity(0.14), location: 0.180),
        .init(color: Color.white.opacity(0.10), location: 0.280),
        .init(color: Color.white.opacity(0.62), location: 0.430),
        .init(color: Color.white.opacity(0.30), location: 0.500),
        .init(color: Color.white.opacity(0.86), location: 0.580),
        .init(color: Color.white.opacity(0.20), location: 0.660),
        .init(color: Color.white.opacity(0.10), location: 0.790),
        .init(color: Color.white.opacity(0.44), location: 0.882),
        .init(color: Color.white.opacity(0.10), location: 0.960),
        .init(color: Color.white.opacity(0.10), location: 1.000),
    ]
    /// La BAGUE : le flare blanc pur du haut-gauche (209°), tracé DEHORS du
    /// bord et flouté — c'est elle, l'« ombre » qui décolle la pièce.
    static let bague: [Gradient.Stop] = [
        .init(color: .white.opacity(0.00), location: 0.000),
        .init(color: .white.opacity(0.00), location: 0.500),
        .init(color: .white.opacity(0.18), location: 0.536),
        .init(color: .white.opacity(0.92), location: 0.581),
        .init(color: .white.opacity(0.30), location: 0.625),
        .init(color: .white.opacity(0.00), location: 0.660),
        .init(color: .white.opacity(0.00), location: 1.000),
    ]
}

// MARK: - Le vent

/// Le souffle de la carte, calculé UNE fois par frame côté CPU — le même
/// bruit de valeur que les autres flammes de l'app : apériodique, avec des
/// accalmies et des reprises, jamais un métronome.
enum JaugeVent {
    private static func hash1(_ n: Float) -> Float {
        let s = sin(n * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    private static func vnoise1(_ x: Float) -> Float {
        let i = floor(x), f = x - floor(x)
        let u = f * f * (3 - 2 * f)
        return hash1(i) * (1 - u) + hash1(i + 1) * u
    }

    /// La respiration lente du halo : 0 repos, 1 pleine braise.
    static func souffle(_ t: Float, phase: Float = 0) -> Float {
        let n = vnoise1(t * 0.32 + phase)
              + 0.5 * vnoise1(t * 0.9 + phase + 47.1)
        return n / 1.5
    }

    /// Le tremblé vif du néon — petit, rapide, celui d'un tube qui vit.
    static func flicker(_ t: Float, phase: Float = 0) -> Float {
        let n = vnoise1(t * 2.6 + phase)
              + 0.45 * vnoise1(t * 6.2 + phase * 1.7 + 13.7)
        return n / 1.45
    }

    /// Une dérive lente et centrée, en [-1 ; 1] — le cœur qui se balance.
    static func derive(_ t: Float, phase: Float = 0) -> Float {
        let n = vnoise1(t * 0.22 + phase)
              + 0.5 * vnoise1(t * 0.57 + phase + 27.9)
        return (n / 1.5 - 0.5) * 2
    }
}

// MARK: - La matière

/// La tuile de grain, générée UNE fois : un bruit gris neutre, tuilé sur la
/// plaque à 3-4 % — c'est lui qui sépare « matière » d'« aplat logiciel ».
enum GrainTexture {
    static let tuile: Image = {
        let size = 96
        var pixels = [UInt8](repeating: 128, count: size * size)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        for i in 0..<pixels.count {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            pixels[i] = UInt8(truncatingIfNeeded: Int(seed >> 56))
        }
        let ctx = CGContext(data: &pixels, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: size,
                            space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return Image(decorative: ctx.makeImage()!, scale: 2)
    }()
}

/// Le losange de la famille diamant — celui des célébrations.
struct DiamantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Le médaillon

/// Le bijou : le shader `jaugeLacque` — un galet mat dans lequel la flamme
/// est extrudée en laque orange, sa lampe qui respire, sa nappe qui déborde.
/// La recette du bouton play de la nav bar, transposée au feu. Autour, en
/// SwiftUI : l'aura que le médaillon pose sur la carte.
struct FlammeMedaillon: View {
    let t: Float
    let date: Date
    let celebrateAt: Date?
    /// L'OUVERTURE de la carte [0,1] : le médaillon s'embrase en
    /// grossissant — la même inspiration que la cérémonie, tenue tant que
    /// la carte est dépliée (le « s'ouvre » du verdict du 15-08).
    var essor: Double = 0
    /// La carte est EN COURSE : la poudre se tait (la loi de fluidité).
    var calme: Bool = false

    /// L'inspiration de la cérémonie : attaque rapide, décrue longue.
    private var boost: Double {
        guard let c = celebrateAt else { return 0 }
        let e = date.timeIntervalSince(c) - 0.30
        guard e > 0, e < 1.2 else { return 0 }
        let q = e / 1.2
        return q < 0.15 ? q / 0.15 : 1 - (q - 0.15) / 0.85
    }

    var body: some View {
        let souffle = Double(JaugeVent.souffle(t))
        let vif = Double(JaugeVent.flicker(t))
        let derive = Double(JaugeVent.derive(t))
        let b = min(1, boost + 0.55 * essor)
        // (L'ONDE EST MORTE — 15-08, « le balayage de la flamme, c'est
        // moche ». Une couleur qui VOYAGE à travers une petite forme est
        // le langage d'un skeleton de chargement, pas d'une flamme : une
        // vraie flamme a une anatomie de couleur STABLE — chaud au pied,
        // or au corps, jaune à la pointe — et ce qui vit, c'est
        // l'intensité et la forme. Le trait ne change donc plus jamais
        // de couleur : la vie est passée DEDANS (les braises qui montent
        // dans la silhouette) et dans la DANSE.)
        ZStack {
            // La niche : le rond chaud que la flamme éclaire — comme la
            // référence, une simple pastille, à peine plus claire au cœur.
            // Elle S'EFFACE à l'ouverture : en grand elle lisait
            // « bouton » — la flamme fine doit vivre seule sur la carte,
            // avec son aura (« pas assez premium », 15-08).
            Circle()
                .fill(RadialGradient(
                    stops: [
                        // Phase 9 restauration : la niche de la référence
                        // est plus CHAUDE et plus claire (sa zone gauche
                        // mesure 0,204 de médiane — la mienne stagnait à
                        // 0,115, tout le déficit vivait ici).
                        // 17-08, ATLAS DU MÉDAILLON (tools/verre/MEDAILLON.md).
                        // Trois défauts mesurés dans ces quatre lignes :
                        //  · LE VOILE GRIS : à r/R ≥ 0,72 je portais +0,040
                        //    sur les TROIS canaux (écart entre canaux 0,005) —
                        //    littéralement « le fond noir qui manque ».
                        //    Sa paroi tient 0,106 de luma, la mienne 0,150.
                        //  · LA CHUTE TROP MOLLE : elle tombe de 2,37× entre
                        //    r/R 0,45 et 0,85, moi de 1,42 — d'où la nappe
                        //    large au lieu d'un bol. endRadius 34 sur un
                        //    rayon de 29 pt portait la lumière à 1,17 R.
                        //  · LE BLEU : B/R valait 0,57 à mi-rayon contre 0,38
                        //    chez elle — un bol gris, pas cuivré. La chaleur
                        //    doit MONTER quand la lumière baisse (X/L 0,89 au
                        //    centre, 0,62 au bord).
                        .init(color: Color(red: 0.350, green: 0.231, blue: 0.120), location: 0.00),
                        .init(color: Color(red: 0.258, green: 0.177, blue: 0.099), location: 0.42),
                        .init(color: Color(red: 0.152, green: 0.113, blue: 0.075), location: 0.72),
                        .init(color: Color(red: 0.108, green: 0.079, blue: 0.058), location: 0.88),
                        .init(color: Color(red: 0.090, green: 0.066, blue: 0.050), location: 1.00),
                    ],
                    // LA PHASE ÉTAIT RETOURNÉE DE 209° : son bol s'éclaircit
                    // vers 71° (le BAS-droite, la flamme l'éclaire par en
                    // dessous), le mien vers 280° (le haut). Le centre du
                    // dégradé doit donc être SOUS le milieu, pas au-dessus.
                    center: UnitPoint(x: 0.516, y: 0.585),
                    startRadius: 0, endRadius: 29))
                // 16-08 : « mets le même médaillon dans la grande carte
                // que dans la mini ». La niche s'effaçait à l'ouverture
                // (`opacity(1 - essor)`), l'anneau aussi, et la taille
                // grossissait de 25 % — le médaillon déplié n'était donc
                // ni le même bijou, ni de la même taille. Mesuré : médiane
                // de l'anneau 0,129 contre 0,613 sur la mini carte.
            // L'ANNEAU (la référence du 15-08) : un cercle d'or net,
            // VIF SUR L'ARC BAS — la flamme l'éclaire par en dessous,
            // comme un chaton de bague pris à contre-jour. Il meurt avec
            // la niche à l'ouverture.
            Circle()
                .strokeBorder(AngularGradient(
                    stops: [
                        // L'ARC ORANGE DU BAS venait d'ICI : un stop
                        // `flamme.opacity(0.88)` à la location 0,32 = 115°.
                        // Mesuré : chromie +0,694 à 115° quand sa photo ne
                        // dépasse JAMAIS +0,181 sur tout le tour. Son liseré
                        // est NEUTRE (chromie médiane +0,10) et fait QUATRE
                        // événements séparés, pas un arc continu :
                        //   18-52°  (bas-droite) pic 0,52, cheveu de 1,05 pt
                        //   303-332° (haut-droite) pic 0,53, cheveu de 1,18
                        //   130-178° (bas-gauche) pic 0,74 — le disque
                        //            découpé dans la clarté de la carte
                        //   190-228° (haut-gauche) pic 0,94 — la BAGUE
                        // Entre les deux cheveux, à 0° pile, elle RETOMBE à
                        // 0,15 : les deux cheveux ENCADRENT l'est.
                        // (locations : 0,00 = 0° = droite, 0,25 = 90° = bas.)
                        .init(color: Color.white.opacity(0.10), location: 0.000),
                        .init(color: Color.white.opacity(0.46), location: 0.098),
                        .init(color: Color.white.opacity(0.14), location: 0.180),
                        .init(color: Color.white.opacity(0.10), location: 0.280),
                        .init(color: Color.white.opacity(0.62), location: 0.430),
                        .init(color: Color.white.opacity(0.30), location: 0.500),
                        .init(color: Color.white.opacity(0.86), location: 0.580),
                        .init(color: Color.white.opacity(0.20), location: 0.660),
                        .init(color: Color.white.opacity(0.10), location: 0.790),
                        .init(color: Color.white.opacity(0.44), location: 0.882),
                        .init(color: Color.white.opacity(0.10), location: 0.960),
                        .init(color: Color.white.opacity(0.10), location: 1.000),
                    ],
                    center: .center,
                    // 0 = à droite ; l'arc vif (0,32) tombe au SUD-OUEST,
                    // comme la référence — la flamme éclaire l'anneau en
                    // contre-plongée gauche.
                    angle: .zero), lineWidth: 0.9)
                .opacity(0.75 + 0.25 * souffle)

            // L'ambiance qui respire — et qui prend sa grande inspiration
            // quand une série se valide.
            // (Le rouge braise est parti d'ici aussi — 15-08 : la nappe
            // reste dans l'or et l'orange, comme le trait.)
            Circle()
                .fill(RadialGradient(
                    stops: [
                        // Divisée par trois : elle rallumait tout le bol en
                        // `plusLighter` et tuait la chute radiale (1,42×
                        // mesuré contre 2,37× chez elle).
                        .init(color: FlammePalette.flamme.opacity(0.06 + 0.03 * souffle + 0.08 * b), location: 0.0),
                        .init(color: FlammePalette.or.opacity(0.02 + 0.015 * souffle), location: 0.55),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 29))
                .blendMode(.plusLighter)

            // LA VIE EST DEDANS, ET LA FORME DANSE — les deux ensemble,
            // la couleur ne bouge JAMAIS. Le tout pivote d'un seul bloc :
            // le masque des braises est dans le même repère que le trait,
            // elles ne peuvent pas en sortir.
            ZStack {
                interieur(t: t, souffle: souffle, vif: vif,
                          derive: derive, b: b)
                ZStack {
                    contour(.light, vif: vif, souffle: souffle, b: b)
                        .opacity(1 - essor)
                    contour(.ultraLight, vif: vif, souffle: souffle, b: b)
                        .opacity(essor)
                }
            }
            // LA DANSE ÉLÉGANTE (son mot : « pas cheap, très élégant »).
            // Trois précautions contre le cartoon : l'amplitude est
            // PETITE (2,4°), le moteur est le bruit LENT de la maison (et
            // jamais une sinusoïde, qui ferait métronome), et l'échelle
            // conserve le volume — la flamme qui s'étire en hauteur se
            // resserre en largeur, comme une matière, pas comme une icône
            // qu'on agrandit. Le pivot est au PIED : c'est la pointe qui
            // mène, le pied reste posé.
            .rotationEffect(.degrees((2.4 + 1.6 * essor) * derive),
                            anchor: .bottom)
            .scaleEffect(x: 1 - 0.030 * souffle,
                         y: 1 + 0.052 * souffle + 0.03 * essor * souffle,
                         anchor: .bottom)
            // Le flottement : un demi-point de dérive verticale, à peine
            // perceptible — c'est ce qui empêche l'objet d'avoir l'air
            // COLLÉ à la carte.
            .offset(y: -0.5 * souffle)

            // LA POUDRE DE DIAMANTS : elle SORT de la flamme — blanche
            // et orange, elle monte, dérive et meurt en cloche. Éteinte
            // pendant la course de la carte (`calme`) : c'est la loi de
            // fluidité de la maison, le détail cède au mouvement.
            if !calme {
                poudre(t: t, souffle: souffle, b: b)
            }
        }
        .frame(width: 58, height: 58)
        // LA FLAQUE (atlas, système F) — le CREUX circulaire accroché au
        // disque : sans lui le médaillon est POSÉ sur le verre, avec lui il y
        // est SERTI. Mesuré chez elle : L(d=6 pt)/L(d=3 pt) = 0,90 dans quatre
        // secteurs sur cinq, fond de cuvette à 0,20 R au-delà de la crête et
        // 23 % sous le plateau ; chez moi le verre MONTAIT (1,01 à 1,21).
        // EN `background` ET PAS DANS LE ZSTACK : un enfant de 98 pt dans un
        // hôte de 58 gonfle l'hôte — payé ici même, le `multiply` a noirci
        // toute la zone et le médaillon a changé de taille. `background` et
        // `overlay` ne pèsent RIEN dans la mesure.
        .background {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        // Le disque fait 29 pt de rayon, le dégradé porte à
                        // 49 : rien ne doit vivre avant 29/49 = 0,592, sinon
                        // la flaque mange le liseré.
                        .init(color: .black.opacity(0.00), location: 0.000),
                        .init(color: .black.opacity(0.00), location: 0.592),
                        .init(color: .black.opacity(0.46), location: 0.714),
                        .init(color: .black.opacity(0.26), location: 0.830),
                        .init(color: .black.opacity(0.00), location: 0.950),
                    ],
                    center: .center, startRadius: 0, endRadius: 49))
                .frame(width: 98, height: 98)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
        // LA BAGUE (atlas, système E) — le flare NEUTRE du haut-gauche, le
        // défaut n° 1 du diagnostic : sa masse vaut 0,93, la mienne valait
        // 0,014 — 67 fois trop faible. Sommet à 209°, largeur à mi-hauteur
        // 25°, pied de 193 à 228°, crête au-dessus de 0,90 de luma et chromie
        // ≤ 0,020 : du blanc PUR, pas de l'or. Trois preuves la disent
        // attachée au disque (sa crête épouse le cercle à ±0,2 pt sur 40°
        // d'arc) mais pilotée par la lumière de la carte — elle n'existe que
        // du côté allumé. `stroke` et non `strokeBorder` : le trait est
        // CENTRÉ sur le cercle, il déborde donc dehors (de 0,99 à 1,15 R)
        // au lieu de rentrer dans le disque.
        // (locations : 0 = 0° = droite, sens horaire ; 209° → 0,581)
        .overlay {
            Circle()
                .stroke(AngularGradient(
                    stops: [
                        .init(color: .white.opacity(0.00), location: 0.000),
                        .init(color: .white.opacity(0.00), location: 0.500),
                        .init(color: .white.opacity(0.18), location: 0.536),
                        .init(color: .white.opacity(0.92), location: 0.581),
                        .init(color: .white.opacity(0.30), location: 0.625),
                        .init(color: .white.opacity(0.00), location: 0.660),
                        .init(color: .white.opacity(0.00), location: 1.000),
                    // LE TOUR DE BAGUE (17-08) : pendant la course, le
                    // reflet blanc FAIT LE TOUR du disque — un éclat qui
                    // glisse sur une pierre qu'on tourne. Un tour complet
                    // exactement : à 0 comme à 1 il retrouve sa place
                    // mesurée (209°), donc les deux états au repos sont
                    // intacts. C'est l'effet le plus LOCAL de la carte, et
                    // c'est voulu — le balayage plein cadre a été refusé.
                    ], center: .center,
                       angle: .degrees(360 * min(max(essor, 0), 1))),
                    lineWidth: 4.5)
                .frame(width: 62, height: 62)
                .blur(radius: 1.5)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .compositingGroup()
    }

    /// L'INTÉRIEUR DE LA FLAMME — l'option 2 : le ventre qui palpite, et
    /// TROIS BRAISES qui naissent au pied, montent dans la silhouette et
    /// s'éteignent avant la pointe. Tout est MASQUÉ par le glyphe plein :
    /// rien ne peut déborder du trait, et c'est ce confinement qui fait
    /// lire « ça brûle » au lieu de « ça scanne ». La différence avec le
    /// balayage refusé : une braise est un petit point MOU qui monte, pas
    /// un dégradé qui traverse toute la forme.
    private func interieur(t: Float, souffle: Double, vif: Double,
                           derive: Double, b: Double) -> some View {
        ZStack {
            // Le ventre : la lueur de fond, qui respire (option 1, gardée
            // en socle — sans elle les braises flottent dans le vide).
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: FlammePalette.or.opacity(0.85),
                              location: 0.0),
                        .init(color: FlammePalette.flamme.opacity(0.45),
                              location: 0.55),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 13))
                .frame(width: 22, height: 22)
                .offset(x: 0.6 * derive, y: 5)
                .scaleEffect(1 + 0.10 * souffle)
                // EN SOURDINE : à pleine puissance, le ventre et les
                // braises fusionnaient en une masse qui palpite — on
                // voyait un blob, pas des points qui montent.
                .opacity(0.19 + 0.10 * souffle + 0.04 * vif + 0.20 * b)
                .blur(radius: 2.8)

            ForEach(0..<3, id: \.self) { i in
                let br = Braise(i: i, t: Double(t))
                Circle()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: FlammePalette.blanc, location: 0),
                            .init(color: FlammePalette.or.opacity(0.55),
                                  location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        center: .center, startRadius: 0, endRadius: br.r))
                    .frame(width: br.r * 2, height: br.r * 2)
                    .offset(x: br.x, y: br.y)
                    .opacity(br.a * (0.40 + 0.20 * souffle + 0.32 * b))
                    .blur(radius: 1.5)
            }
        }
        .blendMode(.plusLighter)
        // LE CONFINEMENT : le glyphe plein sert de masque, à la taille
        // EXACTE du trait — les braises vivent dans la flamme, jamais
        // autour.
        .mask {
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .light))
        }
    }

    /// UNE BRAISE qui monte dans la flamme. Hors du ViewBuilder (la leçon
    /// du vérificateur de types), déterministe : sa phase ne dépend que
    /// du temps et de son indice.
    private struct Braise {
        let x: CGFloat, y: CGFloat, r: CGFloat, a: Double

        init(i: Int, t: Double) {
            let s = Braise.fract(sin(Double(i) * 78.233) * 43758.5453)
            // Une combustion lente : ~2,4 s de vie, décalées entre elles.
            let ph = Braise.fract(t / (2.4 + 0.7 * s) + Double(i) / 3.0)
            // La montée ralentit vers la pointe (la flamme s'y resserre).
            let m = 1 - pow(1 - ph, 2.0)
            y = CGFloat(7.5 - 15.5 * m)
            x = CGFloat((s - 0.5) * 3.2 + 1.1 * sin(t * 0.9 + s * 6.28))
            // Elle rétrécit en montant : le haut de la flamme est étroit.
            // PETITE (4 pt de rayon) : une braise doit rester un POINT de
            // lumière qui monte — au-delà, elle remplit le ventre et
            // redevient une masse qui pulse.
            r = CGFloat(4.0 - 2.0 * m)
            // La cloche : naissance douce, mort avant la pointe.
            a = ph < 0.22 ? ph / 0.22 : max(0, 1 - (ph - 0.22) / 0.62)
        }

        private static func fract(_ x: Double) -> Double {
            x - x.rounded(.down)
        }
    }

    /// Douze micro-diamants, chacun sur son horloge (sa graine décale sa
    /// naissance) : ils naissent au ventre de la flamme, montent en
    /// s'écartant, et s'éteignent en cloche. Blancs pour la moitié,
    /// orange pour l'autre — la famille diamant de l'app, en continu et
    /// en sourdine. Déterministe : aucune horloge aléatoire, tout se
    /// calcule sur `t` (le film se rejoue à l'identique).
    private func poudre(t: Float, souffle: Double, b: Double) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let g = Grain(i: i, t: Double(t))
                DiamantShape()
                    .fill(g.blanche ? FlammePalette.blanc : FlammePalette.or)
                    .frame(width: g.l, height: g.h)
                    .rotationEffect(.degrees(g.tour))
                    .offset(x: g.x, y: g.y)
                    .opacity(g.a * (0.34 + 0.22 * souffle + 0.3 * b))
                    .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }

    /// UN GRAIN de la poudre. Tout se calcule ici, hors du ViewBuilder :
    /// une expression longue dans un `ForEach` fait expirer le
    /// vérificateur de types de Swift (leçon maison). Déterministe — le
    /// hachage ne dépend que de l'indice, la phase que du temps : le même
    /// film se rejoue à l'identique.
    private struct Grain {
        let x: CGFloat, y: CGFloat, l: CGFloat, h: CGFloat
        let a: Double, tour: Double, blanche: Bool

        init(i: Int, t: Double) {
            let s = Grain.fract(sin(Double(i) * 127.1) * 43758.5453)
            let s2 = Grain.fract(sin(Double(i) * 311.7 + 5.3) * 24634.6345)
            blanche = s2 < 0.5
            // Sa vie propre (~1,7 s), sa naissance décalée : jamais deux
            // grains en chœur.
            let ph = Grain.fract(t / (1.7 + 0.6 * s) + s)
            // La montée : du ventre de la flamme vers le haut, en
            // ralentissant — une braise qui s'élève, pas une fusée.
            let mont = 1 - pow(1 - ph, 1.8)
            y = CGFloat(8 - 26 * mont)
            let cote: Double = s2 < 0.5 ? -1 : 1
            x = CGFloat(cote * (1.5 + 7 * mont)
                        + 1.6 * sin(t * 1.7 + s * 6.28))
            // La cloche : naît, brille, meurt — jamais un pop.
            let cloche = ph < 0.18 ? ph / 0.18 : 1 - (ph - 0.18) / 0.82
            a = max(0, cloche)
            // PLUS FINS (« les particules sont trop grosses ») : une
            // poudre est une QUANTITÉ, pas une taille — sous le point,
            // c'est l'anti-crénelage qui fait le grain.
            l = CGFloat(0.9 + 0.6 * s)
            h = CGFloat(1.5 + 0.9 * s)
            tour = 18 * sin(t + s * 6.28)
        }

        private static func fract(_ x: Double) -> Double {
            x - x.rounded(.down)
        }
    }

    /// Le trait de la flamme — FIN (« trop grosse et néon », 15-08) et
    /// VIVANT. Deux choses ont changé : la graisse a maigri d'un cran et
    /// les deux lueurs portées sont divisées par deux (le néon retombe) ;
    /// surtout, la couleur ne dort plus — une ONDE DE LUMIÈRE MONTE dans
    /// le trait, cœur blanc en bas, orange au corps, jaune à la pointe,
    /// et la position de l'onde dérive sur le bruit apériodique de la
    /// maison. C'est le mouvement qui manquait : la flamme ne tremble
    /// plus, elle BRÛLE.
    private func contour(_ poids: Font.Weight, vif: Double,
                         souffle: Double, b: Double) -> some View {
        // L'ANATOMIE DE COULEUR, FIGÉE À JAMAIS : jaune à la pointe, or
        // au corps, orange au pied. Aucun arrêt ne bouge — c'est ce qui
        // sépare une flamme d'un effet de chargement. Et plus de rouge :
        // la rampe s'arrête à l'orange.
        Image(systemName: "flame")
            .font(.system(size: 26, weight: poids))
            .foregroundStyle(LinearGradient(
                stops: [
                    .init(color: FlammePalette.jaune, location: 0.0),
                    .init(color: FlammePalette.or, location: 0.42),
                    .init(color: Color(red: 1.0, green: 0.66, blue: 0.24),
                          location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom))
            .opacity(0.90 + 0.10 * vif)
            .shadow(color: FlammePalette.or.opacity(0.20 + 0.06 * vif),
                    radius: 2.6)
            .shadow(color: FlammePalette.flamme.opacity(0.10
                                                        + 0.05 * souffle
                                                        + 0.12 * b),
                    radius: 6)
    }
}

// MARK: - Les cinq petites flammes

/// La rangée de droite : une flamme par série.
///
/// **REFONTE DU 26-08 — LE STICKER À LA PLACE DU SYMBOLE.** Verdict de
/// Kathryn : « les flammes sont pas assez fines, prends les stickers
/// flamme rouge ». Les deux SF Symbols empilés (un ventre flouté + un
/// contour à deux ombres) sont morts : c'était un TRAIT de symbole, et
/// il coûtait **~3 passes offscreen par flamme allumée** — jusqu'à ~75
/// pour une partition de cinq exercices, même immobiles. Le sticker en
/// coûte ZÉRO.
///
/// ⚠️ L'ASSET EST ROGNÉ À SA BOÎTE UTILE (`sticker-flamme-serree`) :
/// l'original perd **71 % de son canevas en marges transparentes**
/// (384×384 pour une flamme de 180×234), donc à `.frame(16)` on ne
/// voyait qu'une flamme de 7,5 pt — le piège déjà payé au menu (« à
/// 34 pt la coupe mange la moitié du sticker »). Ici le cadre EST la
/// flamme.
struct FlammesRow: View {
    let done: Int
    let total: Int
    let t: Float
    let date: Date
    let igniteAt: Date?
    /// La hauteur d'une flamme, en points. La largeur suit le ratio du
    /// sticker rogné (184/238).
    var corps: CGFloat = 19
    /// LA RÈGLE COMPACTE (variante B) : UNE seule flamme et le compte à
    /// côté, quel que soit le nombre de séries. Faux = la règle A
    /// (jusqu'à cinq flammes, « +X » collé à la dernière).
    var compacte: Bool = false
    /// La cérémonie d'allumage — vraie sur la page détail exercice, où
    /// une série qu'on valide DOIT se voir ; morte dans la partition,
    /// qui n'est qu'un replay.
    var ceremonie: Bool = true

    /// Le ratio du sticker rogné : 184 × 238 px.
    private var largeur: CGFloat { corps * 184 / 238 }

    /// CINQ OBJETS AU PLUS, jamais plus (la loi du 16-08 tient). Ce qui
    /// change : le « +X » ne prend plus la place d'une flamme, il se
    /// COLLE à la dernière — « quand c'est plus de 5, sur la dernière
    /// flamme tu mets +X ».
    private var pleines: Int { compacte ? min(done, 1) : min(done, 5) }
    private var reste: Int { done - pleines }
    /// Les séries qui restent à faire : la MÊME flamme, très
    /// transparente — la rangée dit le contrat autant que l'effort.
    private var vides: Int {
        compacte ? 0 : max(0, min(total - done, 5 - pleines))
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<pleines, id: \.self) { i in
                StickerFlamme(corps: corps, largeur: largeur,
                              eteinte: false, t: t, phase: Float(i) * 4.7,
                              date: date,
                              igniteAt: ceremonie && i == pleines - 1
                                  ? igniteAt : nil)
            }
            if reste > 0 {
                Text("+\(reste)")
                    .font(.inter(11, .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.white.opacity(0.92),
                                 Color.white.opacity(0.38)],
                        startPoint: .top, endPoint: .bottom))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 1)
            }
            ForEach(0..<vides, id: \.self) { i in
                StickerFlamme(corps: corps, largeur: largeur,
                              eteinte: true, t: t,
                              phase: Float(pleines + i) * 4.7,
                              date: date, igniteAt: nil)
            }
        }
    }
}

/// UNE flamme-sticker. Allumée : le sticker plein, qui penche et respire
/// à peine sur SA phase (le tremblé du symbole est mort — un sticker qui
/// vibre en permanence fait cheap). Éteinte : le même sticker à 0,16 —
/// c'est la place vide qui se lit, pas un objet de plus.
struct StickerFlamme: View {
    let corps: CGFloat
    let largeur: CGFloat
    let eteinte: Bool
    let t: Float
    let phase: Float
    let date: Date
    let igniteAt: Date?

    var body: some View {
        let souffle = eteinte ? 0 : JaugeVent.souffle(t, phase: phase * 3.1)
        let sway = eteinte ? 0 : JaugeVent.derive(t, phase: phase + 9.3)
        // La cérémonie : le POP d'échelle du sticker, en cloche — un
        // aller-retour ne se fait jamais en deux animations.
        let e = igniteAt.map { date.timeIntervalSince($0) } ?? 99
        let ceremonie = e >= 0 && e < 0.8
        let pop = ceremonie
            ? 1 + 0.18 * sin(.pi * min(1, e / 0.42)) : 0

        Image("sticker-flamme-serree")
            .resizable()
            .scaledToFit()
            .frame(width: largeur, height: corps)
            .opacity(eteinte ? 0.16 : 1)
            .rotationEffect(.degrees(eteinte ? 0 : Double(sway) * 3.4),
                            anchor: .bottom)
            .scaleEffect(eteinte ? 0.92
                : 1 + 0.03 * CGFloat(souffle) + CGFloat(pop))
            .animation(.spring(response: 0.34, dampingFraction: 0.55),
                       value: eteinte)
            // L'onde et la couronne de la cérémonie vivent AU-DESSUS du
            // sticker, sans rien lui demander (elles sont déjà des
            // couches SwiftUI indépendantes).
            .overlay {
                if ceremonie { CeremonieFlamme(e: e) }
            }
    }
}

/// LA CÉRÉMONIE, sortie de `PetiteFlamme` pour vivre au-dessus du
/// sticker : l'onde et la couronne de six diamants. Le FLASH d'origine
/// (un `flame.fill` surexposé) meurt avec le symbole — c'est le POP
/// d'échelle du sticker qui porte désormais la naissance.
struct CeremonieFlamme: View {
    let e: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let q = min(1, e / 0.8)
        let grandit = 1 - (1 - q) * (1 - q)
        ZStack {
            Circle()
                .stroke(FlammePalette.or.opacity(0.50 * (1 - q)),
                        lineWidth: 0.8)
                .frame(width: 8 + 26 * grandit, height: 8 + 26 * grandit)
                .blendMode(.plusLighter)
            if !reduceMotion {
                ForEach(0..<6, id: \.self) { k in
                    let a = (Double(k) * 60 - 90 + 26 * q) * .pi / 180
                    let r = 6 + 11 * grandit
                    let bell = q < 0.22 ? q / 0.22 : 1 - (q - 0.22) / 0.78
                    DiamantShape()
                        .fill(LinearGradient(
                            colors: [FlammePalette.blanc, FlammePalette.or],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 4.6)
                        .scaleEffect(0.35 + 0.75 * bell)
                        .opacity(bell)
                        .offset(x: r * cos(a), y: r * sin(a))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// L'ANCIENNE flamme-symbole. Plus appelée depuis le 26-08 (le sticker
/// l'a remplacée) — gardée tant que le verdict n'est pas rendu.
struct PetiteFlamme: View {
    let lit: Bool
    let t: Float
    let phase: Float
    let date: Date
    /// L'heure de naissance de CETTE flamme, si elle vient de s'allumer —
    /// la cérémonie (flash, diamants, onde) se déroule dessus.
    let igniteAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let vif = Double(JaugeVent.flicker(t, phase: phase))
        let souffle = Double(JaugeVent.souffle(t, phase: phase * 3.1))
        let sway = Double(JaugeVent.derive(t, phase: phase + 9.3))
        let e = igniteAt.map { date.timeIntervalSince($0) } ?? -1

        ZStack {
            if lit {
                // Le ventre : un cœur d'or qui bat sous le contour, et qui
                // se penche AVEC la flamme — la lumière suit la danse.
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(RadialGradient(
                        stops: [
                            .init(color: FlammePalette.blanc, location: 0.0),
                            .init(color: FlammePalette.or.opacity(0.7), location: 0.45),
                            .init(color: FlammePalette.coeur.opacity(0.0), location: 1.0),
                        ],
                        center: UnitPoint(x: 0.5 + 0.05 * sway, y: 0.66),
                        startRadius: 0, endRadius: 8))
                    .opacity(0.34 + 0.14 * vif + 0.10 * souffle)
                    .blur(radius: 1.3)
                    .blendMode(.plusLighter)
                Image(systemName: "flame")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FlammePalette.neon)
                    .opacity(0.88 + 0.12 * vif)
                    .shadow(color: FlammePalette.coeur.opacity(0.55 + 0.25 * vif), radius: 3)
                    .shadow(color: FlammePalette.braise.opacity(0.28 + 0.18 * souffle), radius: 7)
            } else {
                Image(systemName: "flame")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.16))
            }
        }
        .frame(width: 16, height: 19)
        // La danse : chaque flamme penche depuis son pied et respire à son
        // rythme. Les éteintes ne bougent pas — une flamme morte est immobile.
        .rotationEffect(.degrees(lit ? 3.4 * sway : 0), anchor: .bottom)
        .scaleEffect(lit ? 1.0 + 0.04 * souffle : 0.88)
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: lit)
        .overlay {
            if e >= 0, e < 0.8 {
                ceremonie(e: e)
            }
        }
    }

    /// La cérémonie de naissance : le flash blanc-chaud qui retombe, l'onde
    /// qui s'étend, et la couronne de diamants qui s'écarte en tournant.
    @ViewBuilder
    private func ceremonie(e: Double) -> some View {
        let q = min(1, e / 0.8)
        let grandit = 1 - (1 - q) * (1 - q)
        ZStack {
            // Le flash : la flamme naît surexposée, presque blanche.
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(FlammePalette.blanc)
                .opacity(max(0, 1 - e / 0.32) * 0.85)
                .blur(radius: 1)
                .blendMode(.plusLighter)
            // L'onde : un fin anneau qui se dissout en s'étendant.
            Circle()
                .stroke(FlammePalette.or.opacity(0.50 * (1 - q)), lineWidth: 0.8)
                .frame(width: 8 + 26 * grandit, height: 8 + 26 * grandit)
                .blendMode(.plusLighter)
            // La couronne : six diamants qui naissent sur un cercle,
            // s'écartent et s'éteignent — la famille diamant de l'app.
            if !reduceMotion {
                ForEach(0..<6, id: \.self) { k in
                    let a = (Double(k) * 60 - 90 + 26 * q) * .pi / 180
                    let r = 6 + 11 * grandit
                    let bell = q < 0.22 ? q / 0.22 : 1 - (q - 0.22) / 0.78
                    DiamantShape()
                        .fill(LinearGradient(
                            colors: [FlammePalette.blanc, FlammePalette.or],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 4.6)
                        .scaleEffect(0.35 + 0.75 * bell)
                        .opacity(bell)
                        .offset(x: r * cos(a), y: r * sin(a))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - La jauge

/// La braise couchée : un rail creusé presque noir, le trait de feu braise →
/// or, la POUSSIÈRE DE DIAMANTS qui scintille dedans, et le cap-gemme à la
/// pointe — cœur blanc, anneau d'or, micro-reflet. À chaque série : le trait
/// part en surge, le segment neuf naît blanc-chaud et REFROIDIT vers la
/// rampe, le cap dépasse sa cible et se pose.
struct JaugeBraise: View {
    let done: Int
    let total: Int
    let t: Float
    let date: Date
    let surgeAt: Date?
    let surgeFrom: Int
    /// L'OUVERTURE DE LA CARTE [0,1] — un éclat spéculaire parcourt le
    /// tube pendant le dépliement, comme une lumière qui glisse sur du
    /// verre qu'on incline. Il naît et meurt avec la course : à 0 et à 1
    /// il n'existe pas, la barre au repos est exactement celle d'avant.
    var essor: Double = 0

    // 16-08 : « la progress bar est trop épaisse, je la veux plus fine,
    // avec plus de nuances de jaune pour rappeler la flamme et du blanc
    // pour rappeler le contour de la garde en liquid glass (les cheveux) ».
    // 8 → 5 pt : à 5 pt le tube reste lisible mais cesse d'être une barre.
    private let hauteur: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let frac = CGFloat(done) / CGFloat(total)
            // 17-08 : « à côté du halo il y a le début, un petit bout de
            // la progress bar — enlève-le ». C'était ce `max(hauteur, …)` :
            // à zéro série il forçait une capsule de la hauteur du tube,
            // soit un moignon orange collé au point. À zéro, le tube n'a
            // plus AUCUNE largeur — il ne reste que la pierre, posée au
            // départ du rail.
            let largeur = frac > 0 ? max(hauteur, geo.size.width * frac) : 0
            let vieille = geo.size.width * CGFloat(surgeFrom) / CGFloat(total)
            ZStack(alignment: .leading) {
                // Le rail : creusé, plus sombre en haut — une rainure.
                // LE RAIL ANNONCE L'OR À VENIR (17-08) : au lieu d'un tube
                // gris uniforme, il se réchauffe vers la droite — la
                // partie vide dit déjà de quelle couleur sera le plein.
                // Mesuré sur sa référence : le rail tient 0,24 de luma,
                // le mien 0,06 et sans bord net.
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.50), location: 0.0),
                            .init(color: Color.white.opacity(0.06), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .overlay {
                        Capsule()
                            .fill(LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.10), location: 0.0),
                                    .init(color: FlammePalette.or.opacity(0.13), location: 0.62),
                                    .init(color: FlammePalette.flamme.opacity(0.20), location: 1.0),
                                ],
                                startPoint: .leading, endPoint: .trailing))
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 0.7)
                    }

                braise(largeur: largeur, vieille: vieille)
            }
        }
        .frame(height: hauteur)
    }

    private func braise(largeur: CGFloat, vieille: CGFloat) -> some View {
        let souffle = Double(JaugeVent.souffle(t))
        let vif = Double(JaugeVent.flicker(t, phase: 31.4))
        let eS = surgeAt.map { date.timeIntervalSince($0) } ?? .infinity
        // Le cap dépasse sa cible et se pose — l'overshoot d'une chose qui
        // a une masse.
        let pulse = eS < 1.2 ? 1 + 0.30 * exp(-4.5 * eS) * sin(11 * eS) : 1

        return Capsule()
            .fill(LinearGradient(
                stops: [
                    // LA RAMPE GAGNE SES JAUNES : braise au pied, cœur,
                    // flamme, puis DEUX ors et un jaune franc en tête —
                    // c'est l'anatomie de la flamme du médaillon (jaune à
                    // la pointe, or au corps, orange au pied), transposée
                    // à l'horizontale.
                    .init(color: FlammePalette.braise, location: 0.0),
                    .init(color: FlammePalette.coeur, location: 0.14),
                    .init(color: FlammePalette.flamme, location: 0.42),
                    .init(color: FlammePalette.or, location: 0.68),
                    .init(color: FlammePalette.or, location: 0.86),
                    .init(color: FlammePalette.jaune, location: 1.0),
                ],
                startPoint: .leading, endPoint: .trailing))
            .overlay {
                // LE CŒUR DU TUBE : la ligne blanc-chaud qui court au centre
                // — c'est elle qui fait lire « néon » et non « barre remplie ».
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: FlammePalette.blanc.opacity(0.10), location: 0.0),
                            .init(color: FlammePalette.blanc.opacity(0.75 + 0.10 * vif), location: 0.72),
                            .init(color: FlammePalette.blanc.opacity(0.92), location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: hauteur * 0.34)
                    .padding(.horizontal, 2.5)
                    .blur(radius: 1.1)
                    .blendMode(.plusLighter)
            }
            .overlay {
                // LE LISERÉ : le petit border BLANC dégradé de la référence —
                // brillant en tête, presque rien au pied. C'est le bord de
                // verre du tube.
                // LE CHEVEU BLANC — le liseré de la garde en verre,
                // transposé au tube : un trait de 0,5 pt (au lieu de 1,0)
                // très clair EN HAUT et quasi éteint en bas, exactement
                // comme la tranche haute de la carte. C'est lui que
                // Kathryn appelle « les cheveux ».
                Capsule()
                    .strokeBorder(LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(1.00), location: 0.0),
                            .init(color: Color.white.opacity(0.62), location: 0.28),
                            .init(color: Color.white.opacity(0.16), location: 0.72),
                            .init(color: Color.white.opacity(0.10), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5)
                    .blendMode(.plusLighter)
                    .opacity(0.90 + 0.10 * vif)
            }
            .overlay {
                // LA POUSSIÈRE DE DIAMANTS — le balayage est mort.
                PoussiereDiamants(t: t)
                    .clipShape(Capsule())
            }
            .overlay {
                // L'ÉCLAT DU DÉPLIEMENT : une bande claire, étroite et
                // penchée, qui traverse le tube d'un bout à l'autre
                // pendant que la carte s'ouvre. Sa position SUIT
                // l'ouverture (pas d'animation qui vit sa vie), et son
                // intensité naît puis meurt avec la course — au repos,
                // dans les deux états, elle n'existe pas.
                GeometryReader { g in
                    let vie = sin(min(max(essor, 0), 1) * .pi)
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.85), location: 0.5),
                            .init(color: .white.opacity(0.0), location: 1.0),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 26)
                        .rotationEffect(.degrees(18))
                        .offset(x: (g.size.width + 40) * essor - 20)
                        .opacity(vie)
                        .blendMode(.plusLighter)
                }
                .clipShape(Capsule())
                .allowsHitTesting(false)
            }
            .overlay {
                // Le métal chaud qui refroidit : le segment fraîchement gagné
                // naît blanc-chaud, puis la rampe reprend ses droits.
                if eS < 0.5 {
                    GeometryReader { g in
                        let x0 = min(vieille, g.size.width)
                        Rectangle()
                            .fill(Color.white.opacity(0.42 * (1 - eS / 0.5)))
                            .frame(width: max(0, g.size.width - x0))
                            .offset(x: x0)
                            .blur(radius: 1)
                            .blendMode(.plusLighter)
                    }
                    .clipShape(Capsule())
                }
            }
            .overlay(alignment: .trailing) {
                // LA TRAÎNÉE : quand le point vient d'avancer, une comète
                // courte le suit et s'efface en un demi-tour. Elle ne vit
                // que dans la seconde qui suit la validation — un bijou
                // qui bouge laisse un sillage, un bijou posé n'en a pas.
                if eS < 0.9 {
                    let f = 1 - eS / 0.9
                    LinearGradient(
                        colors: [FlammePalette.or.opacity(0.0),
                                 FlammePalette.or.opacity(0.55 * f)],
                        startPoint: .leading, endPoint: .trailing)
                        .frame(width: 34 * f, height: hauteur * 0.8)
                        .clipShape(Capsule())
                        .blendMode(.plusLighter)
                        .offset(x: -3)
                        .allowsHitTesting(false)
                }
                capGemme(pulse: pulse, vif: vif, souffle: souffle)
            }
            .overlay(alignment: .trailing) {
                // L'ONDE DE VALIDATION : un anneau qui naît au point et
                // s'ouvre en 0,7 s, comme une goutte dans l'eau. Il grandit
                // ET s'efface — jamais l'un sans l'autre, sinon c'est un
                // cercle qui traîne.
                if eS < 0.7 {
                    let w = eS / 0.7
                    Circle()
                        .stroke(FlammePalette.blanc.opacity(0.45 * (1 - w)),
                                lineWidth: 1.2 * (1 - w) + 0.3)
                        .frame(width: 8 + 34 * w, height: 8 + 34 * w)
                        .blendMode(.plusLighter)
                        .offset(x: 2)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: largeur)
            // Le halo du néon : serré et saturé d'abord, large et braise
            // ensuite — c'est le tube qui éclaire la rainure.
            .shadow(color: FlammePalette.coeur.opacity(0.70 + 0.20 * souffle), radius: 4)
            .shadow(color: FlammePalette.coeur.opacity(0.40 + 0.15 * souffle), radius: 9)
            .shadow(color: FlammePalette.braise.opacity(0.30 + 0.15 * souffle), radius: 16)
            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: done)
    }

    /// Le cap-gemme : le point le plus lumineux de la carte — un cœur blanc
    /// serti d'un anneau d'or, avec son micro-reflet haut-gauche.
    /// LE CAP-GEMME — refait le 17-08 sur sa capture de référence. Le
    /// diagnostic était clair : « ton point est un bijou, le mien est une
    /// lampe ». Mesuré au même endroit sur les deux images, mon halo était
    /// un PLATEAU SATURÉ qui tombait d'une falaise — plat à 0,99 jusqu'à
    /// 10 px puis effondré à 0,047 en six pixels — quand le sien descend
    /// doucement de 1,00 à 0,10 sur 34 px. Un bijou n'est pas un point
    /// plus brillant : c'est un point qui RAYONNE LOIN ET FAIBLEMENT.
    /// Cibles prises sur sa capture (en pixels à 3x depuis le centre) :
    /// 0,92 à 6 · 0,67 à 10 · 0,33 à 16 · 0,20 à 24 · 0,10 à 34.
    private func capGemme(pulse: Double, vif: Double,
                          souffle: Double) -> some View {
        // LA RESPIRATION SE FAIT SUR LA PORTÉE, JAMAIS SUR L'AMPLITUDE :
        // moduler l'amplitude clignote, moduler l'étendue respire — la loi
        // de la maison, la même que pour le verre.
        let portee = 1.0 + 0.10 * souffle
        return ZStack {
            // 3. LE HALO LONG, et DORÉ en s'éloignant : blanc au cœur, or
            //    à mi-portée, braise en périphérie — l'anatomie du petit
            //    trait oblique du bas de la carte, transposée en rond.
            //    C'est lui qui relie les deux bijoux de la carte.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        // Doublé après mesure (17-08) : à 10 px du centre
                        // elle tient 0,67 et je tenais 0,28. Un halo de
                        // bijou n'est pas discret, il est LONG — c'est sa
                        // portée qui fait la pierre, pas son cœur.
                        // RESSERRÉ (17-08, tour suivant) : portée 12 → 7,5 pt.
                        // Au tour d'avant j'avais DOUBLÉ la densité sans
                        // toucher à la portée : le halo s'est étalé au lieu
                        // de se concentrer, et il tenait encore 0,41 à 34 px
                        // quand elle est à 0,09 — une grosse boule orange au
                        // lieu d'une pierre. Sa courbe descend VITE (0,77 à
                        // 2 pt, 0,30 à 5,3, 0,09 à 11,3) : c'est une chute,
                        // pas une nappe.
                        .init(color: FlammePalette.blanc.opacity(0.98), location: 0.00),
                        .init(color: FlammePalette.or.opacity(0.72), location: 0.26),
                        .init(color: FlammePalette.flamme.opacity(0.22), location: 0.52),
                        .init(color: FlammePalette.braise.opacity(0.07), location: 0.78),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 7.5 * portee))
                .frame(width: 15 * portee, height: 15 * portee)
            // 2. LE FEU serré : la couronne dorée qui donne la matière.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: FlammePalette.blanc.opacity(0.95), location: 0.0),
                        .init(color: FlammePalette.or.opacity(0.62), location: 0.52),
                        .init(color: FlammePalette.flamme.opacity(0.20), location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 5.1))
                .frame(width: 10.2, height: 10.2)
                .opacity(0.85 + 0.15 * vif)
            // 1. LE CŒUR, petit et franc — c'est la pierre elle-même.
            Circle()
                .fill(Color.white)
                .frame(width: 2.6, height: 2.6)
            // Le micro-reflet haut-gauche : ce qui fait « taillé ».
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 1.0, height: 1.0)
                .offset(x: -1.1, y: -1.2)
        }
        .compositingGroup()
        .blendMode(.plusLighter)
        .scaleEffect(pulse)
        .offset(x: 2)
    }
}

/// Des centaines de petits diamants qui vivent DANS la braise : chacun a sa
/// place, sa vitesse de dérive vers le cap, et son scintillement — une
/// pointe brève (sinus à la puissance 7), pas une pulsation. C'est de la
/// poussière de gemme, pas des paillettes de fête.
struct PoussiereDiamants: View {
    let t: Float

    var body: some View {
        Canvas { ctx, size in
            guard size.width > 4 else { return }
            ctx.blendMode = .plusLighter
            let n = max(60, Int(size.width * 1.8))
            let tt = Double(t)
            for i in 0..<n {
                let h1 = Self.hash(i * 5 + 1)
                let h2 = Self.hash(i * 5 + 2)
                let h3 = Self.hash(i * 5 + 3)
                let h4 = Self.hash(i * 5 + 4)
                let h5 = Self.hash(i * 5 + 5)
                // La dérive : chaque grain avance vers le cap, à sa vitesse.
                let x = ((h1 + tt * 0.020 * (0.4 + 0.8 * h2))
                    .truncatingRemainder(dividingBy: 1)) * size.width
                let y = 1.0 + h2 * (size.height - 2.0)
                // Deux castes : la poussière, qui scintille à peine, et les
                // ÉTOILES (une sur sept), qui jettent de vrais éclats — c'est
                // l'inégalité qui fait le précieux, jamais l'uniforme.
                let etoile = h5 < 0.14
                let tw = 0.5 + 0.5 * sin(tt * (2.2 + 3.4 * h3) + h4 * 6.283)
                let glint = etoile ? pow(tw, 4.0) : pow(tw, 9.0) * 0.45
                guard glint > 0.015 else { continue }
                let s = (etoile ? 0.55 + 0.65 * h4 : 0.28 + 0.42 * h4)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y - s))
                path.addLine(to: CGPoint(x: x + s * 0.62, y: y))
                path.addLine(to: CGPoint(x: x, y: y + s))
                path.addLine(to: CGPoint(x: x - s * 0.62, y: y))
                path.closeSubpath()
                let couleur = h3 < 0.35 ? FlammePalette.blanc : Color.white
                ctx.fill(path, with: .color(couleur.opacity(glint * (0.40 + 0.50 * h2))))
                // L'éclat en croix d'une étoile au sommet de son scintillement.
                if etoile, glint > 0.55 {
                    let f = (glint - 0.55) / 0.45
                    let L = s * (1.6 + 2.2 * f)
                    var croix = Path()
                    croix.move(to: CGPoint(x: x - L, y: y))
                    croix.addLine(to: CGPoint(x: x + L, y: y))
                    croix.move(to: CGPoint(x: x, y: y - L * 0.7))
                    croix.addLine(to: CGPoint(x: x, y: y + L * 0.7))
                    ctx.stroke(croix, with: .color(Color.white.opacity(0.55 * f)),
                               lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }

    static func hash(_ n: Int) -> Double {
        let s = sin(Double(n) * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }
}
