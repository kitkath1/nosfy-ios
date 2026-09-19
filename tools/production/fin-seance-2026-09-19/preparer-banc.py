from pathlib import Path
import sys
r=Path(sys.argv[1]);p=r/'Nosfy/NosfyApp.swift';s=p.read_text()
s=s.replace('DemoData.seedIfEmpty(in: container)','() // Banc isolé : compte local vide, réseau désactivé par -demoData.',1)
s=s.replace('    private func terminerSeance() {','''    private func fixtureFinQA() {
        try? modelContext.delete(model: Workout.self)
        let a = CommandLine.arguments
        let rang = a.contains("-qaSept") ? 7 : 1
        for k in 0..<rang {
            let w = Workout(startedAt: Date().addingTimeInterval(Double(k-rang) * 3600))
            if k < rang-1 { w.endedAt = w.startedAt.addingTimeInterval(600) }
            modelContext.insert(w)
            let e = LoggedExercise(exerciseID: "hip-thrust", order: 0)
            modelContext.insert(e); e.workout = w
            for i in 0..<5 {
                let serie = StrengthSet(reps: 10, weight: 5, order: i, isDone: i == 0)
                modelContext.insert(serie); serie.loggedExercise = e
            }
            if k == rang-1 {
                w.bilanRecompense = try? JSONSerialization.data(withJSONObject:
                    ["pieces": 20, "boosters": 1, "argent": 0])
            }
        }
        try? modelContext.save()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            terminerSeance()
        }
    }

    private func terminerSeance() {''',1)
s=s.replace('        .alert(L("Séance non enregistrée"','''        .overlay(alignment: .topLeading) {
            if CommandLine.arguments.contains("-qaFin"), storyFin == nil, !depart.cheminOuvert {
                Button("QA Fin", action: fixtureFinQA)
                    .accessibilityIdentifier("qa.fin")
                    .frame(width: 80, height: 50).background(.black).opacity(1)
            }
        }
        .alert(L("Séance non enregistrée"''',1)
p.write_text(s)
p=r/'Nosfy/Views/DuolinguoPage.swift';s=p.read_text();s=s.replace('@Environment(\\.accessibilityReduceMotion) private var reduceMotion', '@Environment(\\.accessibilityReduceMotion) private var systemReduceMotion\n    private var reduceMotion: Bool { systemReduceMotion || CommandLine.arguments.contains("-qaReduce") }');s=s.replace('        .sondeCadence("duo")','''        .overlay(alignment: .bottomLeading) {
            Text("faits=\\(etat.faits.count);actif=\\(etat.etape);fete=\\(etat.celebrationValidee ? 1 : 0);chapitre=\\(etat.ecranCourant)")
                .font(.system(size: 1)).opacity(0.01).accessibilityIdentifier("qa.route")
        }
        .sondeCadence("duo")''',1);p.write_text(s)

p=r/"Nosfy/Views/StoryFlow.swift"
s=p.read_text().replace('CommandLine.arguments.contains("-storyProbe")', 'CommandLine.arguments.contains("-qaFin")')
p.write_text(s)
