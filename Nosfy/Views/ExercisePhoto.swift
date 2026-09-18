import SwiftUI

// MARK: - La photo d'exercice

/// L'image d'un exercice : corps en silhouette sur fond NOIR ABSOLU, muscle
/// travaillé en lumière anatomique. Elle a remplacé les figures vectorielles
/// (`ExerciseFigures` / `FigureEngine`, supprimés) partout dans l'app.
///
/// Le fond noir de la photo est le même que celui de la surface diamant : il
/// n'y a aucune couture entre l'image, la carte et la page. C'est ce qui
/// autorise à mélanger les formats — les photos sont en 4:5, 3:4 et 3:2 selon
/// la série, et personne ne peut le voir.
struct ExercisePhoto: View {
    let exercise: Exercise

    /// `true` : la photo REMPLIT le cadre, recadrée au centre — la vignette et
    /// la pastille (le corps entier y serait un fil de lumière illisible ; le
    /// centre de ces images tombe sur le muscle en lumière).
    /// `false` : la photo ENTIÈRE, sans rognage — le héros de la fiche, où le
    /// mouvement complet est l'information.
    var fills: Bool = true

    var body: some View {
        Image(exercise.image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: fills ? .fill : .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Le rognage est DANS le composant : une image `.fill` non coupée
            // déborde silencieusement sur ses voisines, et sur du noir sur du
            // noir on ne s'en aperçoit qu'au moment où un corps traverse une
            // autre carte.
            .clipped()
            .accessibilityLabel(exercise.name)
    }
}
