import SwiftUI

/// Les 16 exercices, chacun décrit par une pose de départ et une pose d'arrivée.
/// Le moteur interpole entre les deux : c'est ce qui produit l'animation du hero.
enum ExerciseFigures {

    static func design(for id: String) -> FigureDesign {
        designs[id] ?? FigureDesign(start: FigurePose(), end: FigurePose())
    }

    private static func pose(_ build: (inout FigurePose) -> Void) -> FigurePose {
        var p = FigurePose()
        build(&p)
        return p
    }

    // MARK: - Table

    private static let designs: [String: FigureDesign] = [

        // MARK: Abdos

        "woop-haute": FigureDesign(
            start: pose {
                $0.head = .init(x: 0.53, y: 0.15); $0.ponytail = .init(x: -0.08, y: 0.05)
                $0.neck = .init(x: 0.52, y: 0.225); $0.chest = .init(x: 0.52, y: 0.31)
                $0.waist = .init(x: 0.51, y: 0.40); $0.hip = .init(x: 0.50, y: 0.475)
                $0.shoulder = .init(x: 0.52, y: 0.25)
                $0.handNear = .init(x: 0.74, y: 0.14); $0.elbowNear = .init(x: 0.64, y: 0.19)
                $0.handFar = .init(x: 0.72, y: 0.17); $0.elbowFar = .init(x: 0.62, y: 0.22)
                $0.kneeNear = .init(x: 0.56, y: 0.66); $0.ankleNear = .init(x: 0.60, y: 0.86)
                $0.kneeFar = .init(x: 0.44, y: 0.66); $0.ankleFar = .init(x: 0.40, y: 0.86)
            },
            end: pose {
                $0.head = .init(x: 0.46, y: 0.20); $0.ponytail = .init(x: -0.02, y: -0.08)
                $0.neck = .init(x: 0.46, y: 0.27); $0.chest = .init(x: 0.45, y: 0.35)
                $0.waist = .init(x: 0.45, y: 0.43); $0.hip = .init(x: 0.48, y: 0.49)
                $0.shoulder = .init(x: 0.46, y: 0.29)
                $0.handNear = .init(x: 0.26, y: 0.62); $0.elbowNear = .init(x: 0.37, y: 0.44)
                $0.handFar = .init(x: 0.28, y: 0.60); $0.elbowFar = .init(x: 0.38, y: 0.43)
                $0.kneeNear = .init(x: 0.56, y: 0.66); $0.ankleNear = .init(x: 0.60, y: 0.86)
                $0.kneeFar = .init(x: 0.44, y: 0.66); $0.ankleFar = .init(x: 0.40, y: 0.86)
            },
            equipment: .cable(anchor: .init(x: 0.88, y: 0.10), attach: .bothHands),
            duration: 1.5
        ),

        "woop-basse": FigureDesign(
            start: pose {
                $0.head = .init(x: 0.48, y: 0.22); $0.ponytail = .init(x: -0.05, y: 0.06)
                $0.neck = .init(x: 0.48, y: 0.29); $0.chest = .init(x: 0.48, y: 0.37)
                $0.waist = .init(x: 0.49, y: 0.44); $0.hip = .init(x: 0.50, y: 0.50)
                $0.shoulder = .init(x: 0.48, y: 0.31)
                $0.handNear = .init(x: 0.70, y: 0.66); $0.elbowNear = .init(x: 0.60, y: 0.50)
                $0.handFar = .init(x: 0.68, y: 0.64); $0.elbowFar = .init(x: 0.59, y: 0.49)
                $0.kneeNear = .init(x: 0.58, y: 0.68); $0.ankleNear = .init(x: 0.60, y: 0.87)
                $0.kneeFar = .init(x: 0.42, y: 0.68); $0.ankleFar = .init(x: 0.40, y: 0.87)
            },
            end: pose {
                $0.head = .init(x: 0.51, y: 0.13); $0.ponytail = .init(x: -0.08, y: 0.02)
                $0.neck = .init(x: 0.51, y: 0.21); $0.chest = .init(x: 0.50, y: 0.30)
                $0.waist = .init(x: 0.50, y: 0.39); $0.hip = .init(x: 0.50, y: 0.47)
                $0.shoulder = .init(x: 0.51, y: 0.23)
                $0.handNear = .init(x: 0.28, y: 0.10); $0.elbowNear = .init(x: 0.40, y: 0.16)
                $0.handFar = .init(x: 0.30, y: 0.13); $0.elbowFar = .init(x: 0.41, y: 0.18)
                $0.kneeNear = .init(x: 0.57, y: 0.66); $0.ankleNear = .init(x: 0.60, y: 0.86)
                $0.kneeFar = .init(x: 0.43, y: 0.66); $0.ankleFar = .init(x: 0.40, y: 0.86)
            },
            equipment: .cable(anchor: .init(x: 0.88, y: 0.84), attach: .bothHands),
            duration: 1.5
        ),

        "flexion-laterale": FigureDesign(
            start: pose {
                $0.handNear = .init(x: 0.63, y: 0.53); $0.elbowNear = .init(x: 0.58, y: 0.40)
                $0.handFar = .init(x: 0.42, y: 0.50); $0.elbowFar = .init(x: 0.44, y: 0.38)
            },
            end: pose {
                $0.head = .init(x: 0.40, y: 0.19); $0.ponytail = .init(x: -0.04, y: 0.07)
                $0.neck = .init(x: 0.42, y: 0.26); $0.chest = .init(x: 0.44, y: 0.335)
                $0.waist = .init(x: 0.47, y: 0.415); $0.hip = .init(x: 0.50, y: 0.478)
                $0.shoulder = .init(x: 0.42, y: 0.28)
                $0.handNear = .init(x: 0.57, y: 0.50); $0.elbowNear = .init(x: 0.52, y: 0.39)
                $0.handFar = .init(x: 0.34, y: 0.50); $0.elbowFar = .init(x: 0.37, y: 0.38)
            },
            equipment: .cable(anchor: .init(x: 0.84, y: 0.84), attach: .nearHand),
            duration: 1.4
        ),

        "rotation-milieu": FigureDesign(
            start: pose {
                $0.head = .init(x: 0.52, y: 0.16); $0.ponytail = .init(x: -0.09, y: 0.03)
                $0.shoulder = .init(x: 0.53, y: 0.258); $0.chest = .init(x: 0.52, y: 0.315)
                $0.handNear = .init(x: 0.72, y: 0.33); $0.elbowNear = .init(x: 0.62, y: 0.31)
                $0.handFar = .init(x: 0.70, y: 0.35); $0.elbowFar = .init(x: 0.61, y: 0.33)
                $0.kneeNear = .init(x: 0.58, y: 0.66); $0.ankleNear = .init(x: 0.62, y: 0.86)
                $0.kneeFar = .init(x: 0.42, y: 0.66); $0.ankleFar = .init(x: 0.38, y: 0.86)
            },
            end: pose {
                $0.head = .init(x: 0.48, y: 0.16); $0.ponytail = .init(x: 0.09, y: 0.03)
                $0.shoulder = .init(x: 0.47, y: 0.258); $0.chest = .init(x: 0.48, y: 0.315)
                $0.handNear = .init(x: 0.28, y: 0.33); $0.elbowNear = .init(x: 0.38, y: 0.31)
                $0.handFar = .init(x: 0.30, y: 0.35); $0.elbowFar = .init(x: 0.39, y: 0.33)
                $0.kneeNear = .init(x: 0.58, y: 0.66); $0.ankleNear = .init(x: 0.62, y: 0.86)
                $0.kneeFar = .init(x: 0.42, y: 0.66); $0.ankleFar = .init(x: 0.38, y: 0.86)
            },
            equipment: .cable(anchor: .init(x: 0.92, y: 0.32), attach: .bothHands),
            duration: 1.5
        ),

        "gainage-militaire": FigureDesign(
            start: plankPose(nearHand: .init(x: 0.34, y: 0.76), nearElbow: .init(x: 0.30, y: 0.68)),
            end: plankPose(nearHand: .init(x: 0.50, y: 0.66), nearElbow: .init(x: 0.42, y: 0.70)),
            equipment: .cable(anchor: .init(x: 0.06, y: 0.88), attach: .nearHand),
            duration: 1.5
        ),

        "gainage-militaire-1j": FigureDesign(
            start: plankPose(nearHand: .init(x: 0.34, y: 0.76), nearElbow: .init(x: 0.30, y: 0.68),
                             legLifted: true),
            end: plankPose(nearHand: .init(x: 0.50, y: 0.66), nearElbow: .init(x: 0.42, y: 0.70),
                           legLifted: true),
            equipment: .cable(anchor: .init(x: 0.06, y: 0.88), attach: .nearHand),
            duration: 1.6
        ),

        "crunch-machine": FigureDesign(
            start: pose {
                $0.head = .init(x: 0.46, y: 0.24); $0.ponytail = .init(x: -0.08, y: 0.03)
                $0.neck = .init(x: 0.47, y: 0.31); $0.chest = .init(x: 0.48, y: 0.39)
                $0.waist = .init(x: 0.49, y: 0.47); $0.hip = .init(x: 0.50, y: 0.545)
                $0.shoulder = .init(x: 0.47, y: 0.33)
                $0.handNear = .init(x: 0.40, y: 0.30); $0.elbowNear = .init(x: 0.40, y: 0.38)
                $0.handFar = .init(x: 0.42, y: 0.32); $0.elbowFar = .init(x: 0.42, y: 0.39)
                $0.kneeNear = .init(x: 0.68, y: 0.60); $0.ankleNear = .init(x: 0.72, y: 0.82)
                $0.kneeFar = .init(x: 0.66, y: 0.62); $0.ankleFar = .init(x: 0.70, y: 0.84)
            },
            end: pose {
                $0.head = .init(x: 0.52, y: 0.38); $0.ponytail = .init(x: -0.09, y: -0.02)
                $0.neck = .init(x: 0.51, y: 0.43); $0.chest = .init(x: 0.51, y: 0.47)
                $0.waist = .init(x: 0.51, y: 0.51); $0.hip = .init(x: 0.50, y: 0.555)
                $0.shoulder = .init(x: 0.51, y: 0.44)
                $0.handNear = .init(x: 0.47, y: 0.41); $0.elbowNear = .init(x: 0.45, y: 0.46)
                $0.handFar = .init(x: 0.49, y: 0.43); $0.elbowFar = .init(x: 0.47, y: 0.47)
                $0.kneeNear = .init(x: 0.68, y: 0.60); $0.ankleNear = .init(x: 0.72, y: 0.82)
                $0.kneeFar = .init(x: 0.66, y: 0.62); $0.ankleFar = .init(x: 0.70, y: 0.84)
            },
            equipment: .crunchMachine,
            duration: 1.3
        ),

        // MARK: Fessiers

        "kickback": FigureDesign(
            start: kickbackPose(knee: .init(x: 0.52, y: 0.66), ankle: .init(x: 0.53, y: 0.86)),
            end: kickbackPose(knee: .init(x: 0.66, y: 0.60), ankle: .init(x: 0.82, y: 0.52)),
            equipment: .cable(anchor: .init(x: 0.92, y: 0.86), attach: .nearAnkle),
            duration: 1.3
        ),

        "pull-through": FigureDesign(
            start: pose {
                $0.head = .init(x: 0.36, y: 0.26); $0.ponytail = .init(x: -0.06, y: -0.04)
                $0.neck = .init(x: 0.40, y: 0.31); $0.chest = .init(x: 0.45, y: 0.36)
                $0.waist = .init(x: 0.51, y: 0.42); $0.hip = .init(x: 0.58, y: 0.47)
                $0.shoulder = .init(x: 0.40, y: 0.33)
                $0.handNear = .init(x: 0.44, y: 0.66); $0.elbowNear = .init(x: 0.42, y: 0.50)
                $0.handFar = .init(x: 0.46, y: 0.67); $0.elbowFar = .init(x: 0.44, y: 0.51)
                $0.kneeNear = .init(x: 0.58, y: 0.66); $0.ankleNear = .init(x: 0.52, y: 0.86)
                $0.kneeFar = .init(x: 0.56, y: 0.67); $0.ankleFar = .init(x: 0.50, y: 0.87)
            },
            end: pose {
                $0.head = .init(x: 0.44, y: 0.15); $0.ponytail = .init(x: -0.08, y: 0.04)
                $0.neck = .init(x: 0.45, y: 0.225); $0.chest = .init(x: 0.46, y: 0.31)
                $0.waist = .init(x: 0.47, y: 0.40); $0.hip = .init(x: 0.48, y: 0.475)
                $0.shoulder = .init(x: 0.45, y: 0.25)
                $0.handNear = .init(x: 0.40, y: 0.50); $0.elbowNear = .init(x: 0.44, y: 0.38)
                $0.handFar = .init(x: 0.42, y: 0.51); $0.elbowFar = .init(x: 0.46, y: 0.39)
                $0.kneeNear = .init(x: 0.50, y: 0.66); $0.ankleNear = .init(x: 0.50, y: 0.86)
                $0.kneeFar = .init(x: 0.46, y: 0.66); $0.ankleFar = .init(x: 0.46, y: 0.87)
            },
            equipment: .cable(anchor: .init(x: 0.92, y: 0.88), attach: .bothHands),
            duration: 1.4
        ),

        "abduction": FigureDesign(
            start: pose {
                $0.handFar = .init(x: 0.42, y: 0.48); $0.elbowFar = .init(x: 0.44, y: 0.37)
                $0.handNear = .init(x: 0.56, y: 0.48); $0.elbowNear = .init(x: 0.55, y: 0.37)
                $0.kneeNear = .init(x: 0.52, y: 0.66); $0.ankleNear = .init(x: 0.52, y: 0.86)
            },
            end: pose {
                $0.head = .init(x: 0.48, y: 0.16)
                $0.handFar = .init(x: 0.40, y: 0.48); $0.elbowFar = .init(x: 0.43, y: 0.37)
                $0.handNear = .init(x: 0.56, y: 0.48); $0.elbowNear = .init(x: 0.55, y: 0.37)
                $0.kneeNear = .init(x: 0.66, y: 0.62); $0.ankleNear = .init(x: 0.80, y: 0.72)
            },
            equipment: .cable(anchor: .init(x: 0.06, y: 0.88), attach: .nearAnkle),
            duration: 1.25
        ),

        "sdt-roumain": FigureDesign(
            start: pose {
                $0.handNear = .init(x: 0.54, y: 0.50); $0.elbowNear = .init(x: 0.53, y: 0.38)
                $0.handFar = .init(x: 0.46, y: 0.50); $0.elbowFar = .init(x: 0.47, y: 0.38)
            },
            end: pose {
                $0.head = .init(x: 0.34, y: 0.30); $0.ponytail = .init(x: -0.05, y: -0.05)
                $0.neck = .init(x: 0.39, y: 0.34); $0.chest = .init(x: 0.45, y: 0.38)
                $0.waist = .init(x: 0.52, y: 0.43); $0.hip = .init(x: 0.60, y: 0.48)
                $0.shoulder = .init(x: 0.39, y: 0.36)
                $0.handNear = .init(x: 0.50, y: 0.68); $0.elbowNear = .init(x: 0.45, y: 0.52)
                $0.handFar = .init(x: 0.46, y: 0.68); $0.elbowFar = .init(x: 0.42, y: 0.52)
                $0.kneeNear = .init(x: 0.58, y: 0.66); $0.ankleNear = .init(x: 0.52, y: 0.86)
                $0.kneeFar = .init(x: 0.54, y: 0.67); $0.ankleFar = .init(x: 0.48, y: 0.87)
            },
            equipment: .cable(anchor: .init(x: 0.90, y: 0.86), attach: .bothHands),
            duration: 1.6
        ),

        "squat-poulie": FigureDesign(
            start: pose {
                $0.handNear = .init(x: 0.44, y: 0.34); $0.elbowNear = .init(x: 0.52, y: 0.36)
                $0.handFar = .init(x: 0.42, y: 0.36); $0.elbowFar = .init(x: 0.50, y: 0.38)
            },
            end: pose {
                $0.head = .init(x: 0.46, y: 0.30); $0.ponytail = .init(x: -0.08, y: 0.02)
                $0.neck = .init(x: 0.47, y: 0.37); $0.chest = .init(x: 0.48, y: 0.44)
                $0.waist = .init(x: 0.50, y: 0.51); $0.hip = .init(x: 0.53, y: 0.58)
                $0.shoulder = .init(x: 0.47, y: 0.39)
                $0.handNear = .init(x: 0.40, y: 0.46); $0.elbowNear = .init(x: 0.48, y: 0.48)
                $0.handFar = .init(x: 0.38, y: 0.48); $0.elbowFar = .init(x: 0.46, y: 0.50)
                $0.kneeNear = .init(x: 0.66, y: 0.66); $0.ankleNear = .init(x: 0.56, y: 0.86)
                $0.kneeFar = .init(x: 0.36, y: 0.67); $0.ankleFar = .init(x: 0.44, y: 0.87)
            },
            equipment: .cable(anchor: .init(x: 0.10, y: 0.84), attach: .bothHands),
            duration: 1.7
        ),

        "hip-thrust": FigureDesign(
            start: hipThrustPose(hip: .init(x: 0.54, y: 0.66), waist: .init(x: 0.47, y: 0.60),
                                 chest: .init(x: 0.40, y: 0.52), kneeNear: .init(x: 0.72, y: 0.66)),
            end: hipThrustPose(hip: .init(x: 0.57, y: 0.53), waist: .init(x: 0.49, y: 0.50),
                               chest: .init(x: 0.41, y: 0.47), kneeNear: .init(x: 0.74, y: 0.62)),
            equipment: .benchHipThrust,
            duration: 1.3
        ),

        // MARK: Cardio

        "hiit-tapis": FigureDesign(
            start: runPose(nearForward: true, amplitude: 1.0),
            end: runPose(nearForward: false, amplitude: 1.0),
            equipment: .treadmill,
            duration: 0.42
        ),

        "escalier": FigureDesign(
            start: pose {
                $0.head = .init(x: 0.44, y: 0.16); $0.ponytail = .init(x: -0.08, y: 0.04)
                $0.neck = .init(x: 0.45, y: 0.235); $0.chest = .init(x: 0.46, y: 0.315)
                $0.waist = .init(x: 0.47, y: 0.405); $0.hip = .init(x: 0.48, y: 0.475)
                $0.shoulder = .init(x: 0.45, y: 0.255)
                $0.handNear = .init(x: 0.58, y: 0.34); $0.elbowNear = .init(x: 0.53, y: 0.34)
                $0.handFar = .init(x: 0.36, y: 0.44); $0.elbowFar = .init(x: 0.42, y: 0.37)
                $0.kneeNear = .init(x: 0.58, y: 0.58); $0.ankleNear = .init(x: 0.60, y: 0.72)
                $0.kneeFar = .init(x: 0.44, y: 0.68); $0.ankleFar = .init(x: 0.40, y: 0.86)
            },
            end: pose {
                $0.head = .init(x: 0.48, y: 0.13); $0.ponytail = .init(x: -0.08, y: 0.05)
                $0.neck = .init(x: 0.49, y: 0.205); $0.chest = .init(x: 0.50, y: 0.29)
                $0.waist = .init(x: 0.51, y: 0.375); $0.hip = .init(x: 0.52, y: 0.45)
                $0.shoulder = .init(x: 0.49, y: 0.225)
                $0.handNear = .init(x: 0.38, y: 0.42); $0.elbowNear = .init(x: 0.44, y: 0.35)
                $0.handFar = .init(x: 0.60, y: 0.32); $0.elbowFar = .init(x: 0.55, y: 0.32)
                $0.kneeNear = .init(x: 0.60, y: 0.55); $0.ankleNear = .init(x: 0.62, y: 0.70)
                $0.kneeFar = .init(x: 0.50, y: 0.62); $0.ankleFar = .init(x: 0.48, y: 0.78)
            },
            equipment: .stairs,
            duration: 0.85
        ),

        "tapis-lent": FigureDesign(
            start: runPose(nearForward: true, amplitude: 0.45),
            end: runPose(nearForward: false, amplitude: 0.45),
            equipment: .treadmill,
            duration: 1.5
        )
    ]

    // MARK: - Poses paramétrées

    /// Planche haute : le corps est horizontal, tête à gauche, pieds à droite.
    private static func plankPose(nearHand: CGPoint, nearElbow: CGPoint,
                                  legLifted: Bool = false) -> FigurePose {
        pose {
            $0.head = .init(x: 0.18, y: 0.52); $0.headRadius = 0.05
            $0.ponytail = .init(x: -0.07, y: -0.03)
            $0.neck = .init(x: 0.26, y: 0.55); $0.chest = .init(x: 0.36, y: 0.585)
            $0.waist = .init(x: 0.48, y: 0.61); $0.hip = .init(x: 0.58, y: 0.625)
            $0.shoulder = .init(x: 0.26, y: 0.57)
            $0.handFar = .init(x: 0.24, y: 0.88); $0.elbowFar = .init(x: 0.25, y: 0.72)
            $0.handNear = nearHand; $0.elbowNear = nearElbow
            $0.kneeNear = .init(x: 0.74, y: 0.70); $0.ankleNear = .init(x: 0.90, y: 0.80)
            if legLifted {
                $0.kneeFar = .init(x: 0.74, y: 0.58); $0.ankleFar = .init(x: 0.90, y: 0.49)
            } else {
                $0.kneeFar = .init(x: 0.74, y: 0.72); $0.ankleFar = .init(x: 0.90, y: 0.83)
            }
        }
    }

    private static func kickbackPose(knee: CGPoint, ankle: CGPoint) -> FigurePose {
        pose {
            $0.head = .init(x: 0.42, y: 0.18); $0.ponytail = .init(x: -0.07, y: 0.03)
            $0.neck = .init(x: 0.44, y: 0.25); $0.chest = .init(x: 0.46, y: 0.33)
            $0.waist = .init(x: 0.48, y: 0.41); $0.hip = .init(x: 0.50, y: 0.48)
            $0.shoulder = .init(x: 0.44, y: 0.27)
            $0.handNear = .init(x: 0.30, y: 0.42); $0.elbowNear = .init(x: 0.37, y: 0.35)
            $0.handFar = .init(x: 0.32, y: 0.44); $0.elbowFar = .init(x: 0.38, y: 0.37)
            $0.kneeNear = knee; $0.ankleNear = ankle
            $0.kneeFar = .init(x: 0.47, y: 0.66); $0.ankleFar = .init(x: 0.46, y: 0.87)
        }
    }

    private static func hipThrustPose(hip: CGPoint, waist: CGPoint, chest: CGPoint,
                                      kneeNear: CGPoint) -> FigurePose {
        pose {
            $0.head = .init(x: 0.26, y: 0.40); $0.headRadius = 0.05
            $0.ponytail = .init(x: -0.06, y: -0.02)
            $0.neck = .init(x: 0.33, y: 0.44); $0.chest = chest
            $0.waist = waist; $0.hip = hip
            $0.shoulder = .init(x: 0.33, y: 0.45)
            $0.handNear = .init(x: 0.48, y: 0.60); $0.elbowNear = .init(x: 0.40, y: 0.52)
            $0.handFar = .init(x: 0.46, y: 0.62); $0.elbowFar = .init(x: 0.38, y: 0.54)
            $0.kneeNear = kneeNear; $0.ankleNear = .init(x: 0.74, y: 0.88)
            $0.kneeFar = .init(x: kneeNear.x - 0.02, y: kneeNear.y + 0.02)
            $0.ankleFar = .init(x: 0.72, y: 0.89)
        }
    }

    /// Foulée. `nearForward` place la jambe proche devant ; `amplitude` distingue
    /// la course (1.0) de la marche (0.45).
    private static func runPose(nearForward: Bool, amplitude: CGFloat) -> FigurePose {
        func mix(_ rest: CGFloat, _ extreme: CGFloat) -> CGFloat {
            rest + (extreme - rest) * amplitude
        }
        let forwardKnee = CGPoint(x: mix(0.52, 0.62), y: mix(0.66, 0.60))
        let forwardAnkle = CGPoint(x: mix(0.52, 0.68), y: mix(0.86, 0.76))
        let backKnee = CGPoint(x: mix(0.48, 0.42), y: 0.66)
        let backAnkle = CGPoint(x: mix(0.48, 0.34), y: mix(0.86, 0.84))
        let forwardHand = CGPoint(x: mix(0.54, 0.62), y: mix(0.44, 0.30))
        let forwardElbow = CGPoint(x: mix(0.53, 0.56), y: mix(0.38, 0.36))
        let backHand = CGPoint(x: mix(0.46, 0.36), y: mix(0.44, 0.42))
        let backElbow = CGPoint(x: mix(0.47, 0.42), y: mix(0.38, 0.36))

        return pose {
            $0.head = .init(x: 0.48, y: nearForward ? 0.15 : 0.16)
            $0.ponytail = .init(x: -0.09, y: nearForward ? 0.02 : 0.05)
            $0.neck = .init(x: 0.48, y: 0.235); $0.chest = .init(x: 0.49, y: 0.315)
            $0.waist = .init(x: 0.49, y: 0.405); $0.hip = .init(x: 0.49, y: 0.475)
            $0.shoulder = .init(x: 0.48, y: 0.255)
            $0.handNear = nearForward ? forwardHand : backHand
            $0.elbowNear = nearForward ? forwardElbow : backElbow
            $0.handFar = nearForward ? backHand : forwardHand
            $0.elbowFar = nearForward ? backElbow : forwardElbow
            $0.kneeNear = nearForward ? forwardKnee : backKnee
            $0.ankleNear = nearForward ? forwardAnkle : backAnkle
            $0.kneeFar = nearForward ? backKnee : forwardKnee
            $0.ankleFar = nearForward ? backAnkle : forwardAnkle
        }
    }
}
