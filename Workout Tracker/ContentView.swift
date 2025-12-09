import SwiftUI
import CoreData

// MARK: - Optional Fields Store (lightweight persistence without Core Data changes)
struct OptionalFieldsStore {
    static let shared = OptionalFieldsStore()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "setOptionalFields_" // key: keyPrefix + setID

    func save(fields: [OptionalField: String], for setID: UUID) {
        let dict = Dictionary(uniqueKeysWithValues: fields.map { ($0.key.storageKey, $0.value) })
        defaults.set(dict, forKey: keyPrefix + setID.uuidString)
    }

    func load(for setID: UUID) -> [String: String] {
        return defaults.dictionary(forKey: keyPrefix + setID.uuidString) as? [String: String] ?? [:]
    }
}

private extension OptionalField {
    var storageKey: String {
        switch self {
        case .seatHeight: return "seatHeight"
        case .barHeight: return "barHeight"
        case .seatAngle: return "seatAngle"
        case .footPlacement: return "footPlacement"
        case .lean: return "lean"
        case .cableHeight: return "cableHeight"
        case .myoReps: return "myoReps"
        }
    }
}

// MARK: - In-Progress Workout Persistence

struct InProgressWorkout: Codable {
    var sessionType: String
    var workoutDate: Date
    var loggedExercises: [LoggedExerciseCodable]
}

struct LoggedExerciseCodable: Codable {
    var name: String
    var sets: [LoggedSetCodable]
}

struct LoggedSetCodable: Codable {
    var setNumber: Int
    var weight: String
    var reps: String
    // Optional details
    var seatHeight: Int?
    var barHeight: Int?
    var seatAngle: Int?
    var footPlacement: String
    var lean: Bool
    var cableHeight: Int?
    var myoReps: String
}

final class InProgressWorkoutStore {
    static let shared = InProgressWorkoutStore()
    private let key = "inProgressWorkout_v1"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ model: InProgressWorkout) {
        if let data = try? encoder.encode(model) {
            defaults.set(data, forKey: key)
        }
    }

    func load() -> InProgressWorkout? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(InProgressWorkout.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

private extension LoggedSet {
    init(from codable: LoggedSetCodable) {
        self.init(
            setNumber: codable.setNumber,
            weight: codable.weight,
            reps: codable.reps,
            seatHeight: codable.seatHeight,
            barHeight: codable.barHeight,
            seatAngle: codable.seatAngle,
            footPlacement: codable.footPlacement,
            lean: codable.lean,
            cableHeight: codable.cableHeight,
            myoReps: codable.myoReps
        )
    }
    var codable: LoggedSetCodable {
        LoggedSetCodable(
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            seatHeight: seatHeight,
            barHeight: barHeight,
            seatAngle: seatAngle,
            footPlacement: footPlacement,
            lean: lean,
            cableHeight: cableHeight,
            myoReps: myoReps
        )
    }
}

// MARK: - Helper to detect to-many relationship
private func isToManyRelationship(_ object: NSManagedObject, key: String) -> Bool {
    return object.entity.relationshipsByName[key]?.isToMany == true
}

// MARK: - Exercise Usage Tracker

class ExerciseUsageTracker {
    static let shared = ExerciseUsageTracker()
    private let keyPrefix = "exerciseUsage_"
    private let threshold = 3 // Number of workouts before showing suggestions

    func logExercise(sessionType: String, exerciseName: String) {
        let key = keyPrefix + sessionType
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        dict[exerciseName, default: 0] += 1
        UserDefaults.standard.setValue(dict, forKey: key)
    }
    
    func commonExercises(for sessionType: String, count: Int = 6) -> [String] {
        let key = keyPrefix + sessionType
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return Array(dict.sorted { $0.value > $1.value }.prefix(count).map { $0.key })
    }
    
    func hasEnoughHistory(for sessionType: String) -> Bool {
        let key = keyPrefix + sessionType
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        let total = dict.values.reduce(0, +)
        return total >= threshold
    }
    
    func allSavedExercises() -> [String] {
        let defaults = UserDefaults.standard
        var allExercisesSet = Set<String>()
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            if let dict = defaults.dictionary(forKey: key) as? [String: Int] {
                for exercise in dict.keys {
                    allExercisesSet.insert(exercise)
                }
            }
        }
        return Array(allExercisesSet).sorted()
    }
}

// MARK: - Simple in-memory models for the current workout screen

struct LoggedSet: Identifiable, Equatable {
    let id = UUID()
    var setNumber: Int
    var weight: String
    var reps: String

    // Optional additional attributes captured per set
    var seatHeight: Int? = nil
    var barHeight: Int? = nil
    var seatAngle: Int? = nil
    var footPlacement: String = ""
    var lean: Bool = false
    var cableHeight: Int? = nil
    var myoReps: String = ""
}

struct LoggedExercise: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var sets: [LoggedSet]

    static func == (lhs: LoggedExercise, rhs: LoggedExercise) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Optional per-set fields definition
enum OptionalField: CaseIterable, Hashable {
    case seatHeight
    case barHeight
    case seatAngle
    case footPlacement
    case lean
    case cableHeight
    case myoReps

    var title: String {
        switch self {
        case .seatHeight: return "Seat Height"
        case .barHeight: return "Bar Height"
        case .seatAngle: return "Seat Angle"
        case .footPlacement: return "Foot Placement"
        case .lean: return "Lean"
        case .cableHeight: return "Cable Height"
        case .myoReps: return "MyoReps"
        }
    }

    var placeholder: String {
        switch self {
        case .seatHeight: return "e.g., 5"
        case .barHeight: return "e.g., 3"
        case .seatAngle: return "e.g., 30°"
        case .footPlacement: return "e.g., middle"
        case .lean: return "e.g., slight"
        case .cableHeight: return "e.g., 10"
        case .myoReps: return "e.g., 3-3-3"
        }
    }
}

extension LoggedSet {
    // Binding accessors to map OptionalField to the correct stored property
    var fieldValuePairs: [(OptionalField, String)] {
        [
            (.seatHeight, seatHeight.map(String.init) ?? ""),
            (.barHeight, barHeight.map(String.init) ?? ""),
            (.seatAngle, seatAngle.map(String.init) ?? ""),
            (.footPlacement, footPlacement),
            (.lean, lean ? "true" : "false"),
            (.cableHeight, cableHeight.map(String.init) ?? ""),
            (.myoReps, myoReps)
        ]
    }
}

// MARK: - Session Types

let sessionTypes: [String] = [
    "Pull",
    "Push",
    "Legs/Abs",
    "Back/Chest",
    "Arms",
    "Abs/Legs",
    "Other"
]

// MARK: - Exercise Presets

struct ExercisePresets {
    static let exercisesBySessionType: [String: [String]] = [
        "Push": [
            "Barbell Bench Press",
            "Incline Dumbbell Press",
            "Overhead Press",
            "Dumbbell Shoulder Press",
            "Chest Fly",
            "Tricep Pushdown"
        ],
        "Pull": [
            "Deadlift",
            "Barbell Row",
            "Lat Pulldown",
            "Seated Row",
            "Face Pull",
            "Bicep Curl"
        ],
        "Legs": [
            "Back Squat",
            "Front Squat",
            "Romanian Deadlift",
            "Leg Press",
            "Leg Extension",
            "Hamstring Curl"
        ],
        "Upper": [
            "Bench Press",
            "Pull Up",
            "Row",
            "Shoulder Press",
            "Bicep Curl",
            "Tricep Extension"
        ],
        "Lower": [
            "Squat",
            "Deadlift",
            "Leg Press",
            "Lunge",
            "Calf Raise",
            "Glute Bridge"
        ],
        "Full Body": [
            "Squat",
            "Bench Press",
            "Row",
            "Overhead Press",
            "Deadlift",
            "Pull Up"
        ],
        "Cardio": [
            "Treadmill",
            "Bike",
            "Rowing Machine",
            "Stair Climber",
            "Elliptical",
            "Outdoor Run"
        ]
    ]
}

// MARK: - Home Screen

struct ContentView: View {
    @State private var resumeModel: InProgressWorkout? = InProgressWorkoutStore.shared.load()
    @State private var resumeNavTrigger: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if resumeModel != nil {
                        Button {
                            resumeNavTrigger = true
                        } label: {
                            Text("Resume Workout")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    NavigationLink {
                        AddWorkoutView()
                    } label: {
                        Text("Add Workout")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)

                    NavigationLink {
                        ExportDataView()
                    } label: {
                        Text("Export Data")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        HistoryView()
                    } label: {
                        Text("History")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Gym Tracker")
            .onAppear {
                resumeModel = InProgressWorkoutStore.shared.load()
            }
            .navigationDestination(isPresented: $resumeNavTrigger) {
                if let model = resumeModel {
                    ExerciseSelectionView(
                        sessionType: model.sessionType,
                        workoutDate: model.workoutDate,
                        initialLoggedExercises: model.loggedExercises.map { LoggedExercise(name: $0.name, sets: $0.sets.map { LoggedSet(from: $0) }) }
                    )
                } else {
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Add Workout Screen

struct AddWorkoutView: View {
    private let workoutDate = Date()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("New Workout")
                    .font(.largeTitle)
                    .bold()
                
                Text("Date: \(workoutDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Text("What type of session will you be doing?")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ForEach(sessionTypes, id: \.self) { type in
                        NavigationLink {
                            ExerciseSelectionView(
                                sessionType: type,
                                workoutDate: workoutDate
                            )
                        } label: {
                            HStack {
                                Text(type)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .navigationTitle("Add Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise Selection Screen

struct ExerciseSelectionView: View {
    let sessionType: String
    let workoutDate: Date
    let initialLoggedExercises: [LoggedExercise]?

    init(sessionType: String, workoutDate: Date, initialLoggedExercises: [LoggedExercise]? = nil) {
        self.sessionType = sessionType
        self.workoutDate = workoutDate
        self.initialLoggedExercises = initialLoggedExercises
    }
    
    @State private var loggedExercises: [LoggedExercise] = []
    @State private var showingAddNewPrompt: Bool = false
    @State private var newExerciseName: String = ""
    @State private var showingExerciseDetail: Bool = false
    
    @State private var showingSearchPrompt: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [String] = []
    @State private var selectedSearchExercise: String?
    
    @State private var isEditingExercise: Bool = false
    @State private var editingExerciseIndex: Int? = nil
    @State private var showingEraseConfirm: Bool = false
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    private func persistProgress() {
        let model = InProgressWorkout(
            sessionType: sessionType,
            workoutDate: workoutDate,
            loggedExercises: loggedExercises.map { le in
                LoggedExerciseCodable(
                    name: le.name,
                    sets: le.sets.map { $0.codable }
                )
            }
        )
        InProgressWorkoutStore.shared.save(model)
    }
    
    var exercises: [String] {
        if ExerciseUsageTracker.shared.hasEnoughHistory(for: sessionType) {
            return ExerciseUsageTracker.shared.commonExercises(for: sessionType)
        } else {
            return []
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(sessionType) Session")
                    .font(.largeTitle)
                    .bold()
                
                Text("Date: \(workoutDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                if !exercises.isEmpty {
                    Text("Select an exercise:")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        ForEach(exercises, id: \.self) { exercise in
                            NavigationLink {
                                ExerciseDetailView(
                                    exerciseName: exercise,
                                    onLog: { sets in
                                        let logged = LoggedExercise(name: exercise, sets: sets)
                                        loggedExercises.append(logged)
                                        persistProgress()
                                        ExerciseUsageTracker.shared.logExercise(sessionType: sessionType, exerciseName: exercise)
                                    }
                                )
                            } label: {
                                HStack {
                                    Text(exercise)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                if !loggedExercises.isEmpty {
                    Divider()
                    Text("Logged so far:")
                        .font(.headline)
                    ForEach(Array(loggedExercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            editingExerciseIndex = index
                            isEditingExercise = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .bold()
                                    Text("\(exercise.sets.count) set(s)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.pencil")
                                    .imageScale(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Tap to edit a logged exercise before finishing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        showingAddNewPrompt = true
                    } label: {
                        Text("Add New")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        showingSearchPrompt = true
                        searchText = ""
                        searchResults = []
                    } label: {
                        Text("Search")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        finishWorkout()
                    } label: {
                        Text("Finish Workout")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        showingEraseConfirm = true
                    } label: {
                        Text("Erase Current Workout")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enter Exercise Name", isPresented: $showingAddNewPrompt, actions: {
            TextField("Exercise name", text: $newExerciseName)
            Button("Cancel", role: .cancel) {
                newExerciseName = ""
            }
            Button("Add") {
                let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                showingExerciseDetail = true
            }
            .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        })
        .sheet(isPresented: $showingExerciseDetail) {
            ExerciseDetailView(
                exerciseName: newExerciseName,
                onLog: { sets in
                    let logged = LoggedExercise(name: newExerciseName, sets: sets)
                    loggedExercises.append(logged)
                    persistProgress()
                    ExerciseUsageTracker.shared.logExercise(sessionType: sessionType, exerciseName: newExerciseName)
                    newExerciseName = ""
                    showingExerciseDetail = false
                }
            )
        }
        .sheet(isPresented: $showingSearchPrompt) {
            NavigationStack {
                VStack {
                    TextField("Search exercises", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                        .onChange(of: searchText) { _, newValue in
                            let allExercises = ExerciseUsageTracker.shared.allSavedExercises()
                            if newValue.isEmpty {
                                searchResults = []
                            } else {
                                searchResults = allExercises.filter {
                                    $0.range(of: newValue, options: .caseInsensitive) != nil
                                }
                            }
                        }
                    
                    if searchResults.isEmpty && !searchText.isEmpty {
                        Text("No matches found")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    List {
                        ForEach(searchResults, id: \.self) { exercise in
                            Button {
                                selectedSearchExercise = exercise
                                showingSearchPrompt = false
                            } label: {
                                Text(exercise)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .navigationTitle("Search Exercises")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingSearchPrompt = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingExercise) {
            if let idx = editingExerciseIndex, loggedExercises.indices.contains(idx) {
                let ex = loggedExercises[idx]
                ExerciseDetailView(
                    exerciseName: ex.name,
                    onLog: { updatedSets in
                        // Replace the exercise at idx with updated sets
                        var updated = loggedExercises
                        updated[idx] = LoggedExercise(name: ex.name, sets: updatedSets)
                        loggedExercises = updated
                        persistProgress()
                        isEditingExercise = false
                        editingExerciseIndex = nil
                    },
                    sets: ex.sets
                )
            }
        }
        .onChange(of: selectedSearchExercise) { _, newValue in
            if let exercise = newValue {
                showingExerciseDetail = true
                newExerciseName = exercise
                selectedSearchExercise = nil
            }
        }
        .onAppear {
            if loggedExercises.isEmpty {
                if let initial = initialLoggedExercises {
                    loggedExercises = initial
                } else if let stored = InProgressWorkoutStore.shared.load(), stored.sessionType == sessionType {
                    loggedExercises = stored.loggedExercises.map { LoggedExercise(name: $0.name, sets: $0.sets.map { LoggedSet(from: $0) }) }
                }
            }
        }
        .onChange(of: loggedExercises) { _, _ in
            persistProgress()
        }
        .alert("Erase current workout?", isPresented: $showingEraseConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Erase", role: .destructive) {
                // Clear in-progress workout data
                loggedExercises.removeAll()
                InProgressWorkoutStore.shared.clear()
                // Also reset any resume state on the home screen by popping back
                dismiss()
            }
        } message: {
            Text("This will remove all exercises and sets you've logged in this in-progress workout.")
        }
    }
    
    private func finishWorkout() {
        // Only include exercises that have at least one set with data
        
        // Ensure Core Data context is configured
        if viewContext.persistentStoreCoordinator == nil {
            print("Error: ManagedObjectContext has no persistentStoreCoordinator. Aborting save to avoid crash.")
            dismiss()
            return
        }
        
        print("FinishWorkout tapped. Logged exercises count: \(loggedExercises.count)")
        let nonEmptyExercises = loggedExercises.filter { exercise in
            exercise.sets.contains { !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        print("Non-empty exercises to save: \(nonEmptyExercises.map{ $0.name + "(\($0.sets.count))" }.joined(separator: ", "))")
        
        guard !nonEmptyExercises.isEmpty else {
            print("No non-empty exercises. Aborting save and dismissing.")
            dismiss()
            return
        }
        
        // Create the workout up front so we can attach exercises to it
        let workout = Workout(context: viewContext)
        workout.id = UUID()
        workout.date = workoutDate
        workout.sessionType = sessionType
        
        for (index, loggedExercise) in nonEmptyExercises.enumerated() {
            // Only persist sets that have weight or reps provided
            let nonEmptySets = loggedExercise.sets.filter { set in
                let hasWeight = !set.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasReps = !set.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return hasWeight || hasReps
            }
            
            guard !nonEmptySets.isEmpty else { continue }
            
            let exercise = ExerciseEntry(context: viewContext)
            exercise.id = UUID()
            exercise.name = loggedExercise.name
            exercise.order = Int16(index)
            exercise.workout = workout
            
            for loggedSet in nonEmptySets {
                let setEntry = SetEntry(context: viewContext)
                setEntry.id = UUID()
                let setID = setEntry.id ?? UUID()
                setEntry.setNumber = Int16(loggedSet.setNumber)
                setEntry.weight = Double(loggedSet.weight) ?? 0.0

                let repsString = loggedSet.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                let repsValue: Int = {
                    if repsString.contains("-") {
                        return repsString.split(separator: "-")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .compactMap { Int($0) }
                            .reduce(0, +)
                    } else {
                        return Int(repsString) ?? 0
                    }
                }()
                setEntry.reps = Int16(repsValue)

                setEntry.exercise = exercise

                var optionalDict: [OptionalField: String] = [:]
                if let v = loggedSet.seatHeight { optionalDict[.seatHeight] = String(v) }
                if let v = loggedSet.barHeight { optionalDict[.barHeight] = String(v) }
                if let v = loggedSet.seatAngle { optionalDict[.seatAngle] = String(v) }
                if !loggedSet.footPlacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { optionalDict[.footPlacement] = loggedSet.footPlacement }
                if loggedSet.lean { optionalDict[.lean] = "true" }
                if let v = loggedSet.cableHeight { optionalDict[.cableHeight] = String(v) }
                if !loggedSet.myoReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { optionalDict[.myoReps] = loggedSet.myoReps }
                if !optionalDict.isEmpty {
                    OptionalFieldsStore.shared.save(fields: optionalDict, for: setID)
                }
            }
        }
        print("Saving workout on date: \(workoutDate), session: \(sessionType), exercises: \(nonEmptyExercises.count)")
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving workout: \(error)")
            assertionFailure("Core Data save failed: \(error)")
        }
        
        dismiss()
        InProgressWorkoutStore.shared.clear()
    }
}

// MARK: - Exercise Detail (Sets Entry)

struct ExerciseDetailView: View {
    let exerciseName: String
    let onLog: ([LoggedSet]) -> Void
    
    @Environment(\.dismiss) private var dismiss

    @Environment(\.managedObjectContext) private var viewContext

    // History summaries
    @State private var latestWeight: Double? = nil
    @State private var lastLogSummary: String = ""
    @State private var bestAtWeightSummary: String = ""
    
    // Toggles to enable optional fields
    @State private var enabledFields: Set<OptionalField> = []
    
    @State private var sets: [LoggedSet]

    private struct SyncedFields {
        var weight: Bool = true
        var reps: Bool = true
        var seatHeight: Bool = true
        var barHeight: Bool = true
        var seatAngle: Bool = true
        var footPlacement: Bool = true
        var lean: Bool = true
        var cableHeight: Bool = true
        var myoReps: Bool = true
    }
    @State private var synced: [Int: SyncedFields] = [:]
    @State private var isProgrammaticUpdate: Bool = false

    @State private var propagateWorkItem: DispatchWorkItem?

    private func schedulePropagation() {
        propagateWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            propagateFromFirstSet()
        }
        propagateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: workItem)
    }
    
    init(exerciseName: String, onLog: @escaping ([LoggedSet]) -> Void, sets: [LoggedSet]? = nil) {
        self.exerciseName = exerciseName
        self.onLog = onLog
        _sets = State(initialValue: sets ?? (1...5).map {
            LoggedSet(setNumber: $0, weight: "", reps: "")
        })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exerciseName)
                    .font(.largeTitle)
                    .bold()
                
                Text("Enter weight and reps for each set.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    if !lastLogSummary.isEmpty {
                        Text(lastLogSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                    if !bestAtWeightSummary.isEmpty {
                        Text(bestAtWeightSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional Details")
                        .font(.headline)
                    Text("Select any additional details to record for each set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(OptionalField.allCases, id: \.self) { field in
                        Toggle(field.title, isOn: Binding(
                            get: { enabledFields.contains(field) },
                            set: { isOn in
                                if isOn { enabledFields.insert(field) } else { enabledFields.remove(field) }
                            }
                        ))
                    }
                }
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 12) {
                        if sets.indices.contains(0) {
                            HStack(spacing: 12) {
                                Text("Set 1")
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading) {
                                    Text("Weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("kg", text: $sets[0].weight)
                                        .keyboardType(.decimalPad)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .onSubmit {
                                            if sets.indices.contains(1) { sets[1].weight = sets[0].weight }
                                            if sets.indices.contains(2) { sets[2].weight = sets[0].weight }
                                        }
                                        .onChange(of: sets[0].weight) { _, _ in
                                            if sets.indices.contains(1) { sets[1].weight = sets[0].weight }
                                            if sets.indices.contains(2) { sets[2].weight = sets[0].weight }
                                        }
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading) {
                                    Text("Reps")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("reps", text: $sets[0].reps)
                                        .keyboardType(enabledFields.contains(.myoReps) ? .numbersAndPunctuation : .numberPad)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .onSubmit {
                                            if sets.indices.contains(1) { sets[1].reps = sets[0].reps }
                                            if sets.indices.contains(2) { sets[2].reps = sets[0].reps }
                                        }
                                        .onChange(of: sets[0].reps) { _, _ in
                                            if sets.indices.contains(1) { sets[1].reps = sets[0].reps }
                                            if sets.indices.contains(2) { sets[2].reps = sets[0].reps }
                                        }
                                        .textFieldStyle(.roundedBorder)
                                }
                                ForEach(Array(enabledFields), id: \.self) { field in
                                    VStack(alignment: .leading) {
                                        Text(field.title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        switch field {
                                        case .seatHeight:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[0].seatHeight.map(String.init) ?? "" },
                                                set: { sets[0].seatHeight = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit { if enabledFields.contains(.seatHeight) { schedulePropagation() } }
                                            .onSubmit {
                                                if enabledFields.contains(.seatHeight) {
                                                    if sets.indices.contains(1) { sets[1].seatHeight = sets[0].seatHeight }
                                                    if sets.indices.contains(2) { sets[2].seatHeight = sets[0].seatHeight }
                                                }
                                            }
                                            .onChange(of: sets[0].seatHeight) { _, _ in
                                                if enabledFields.contains(.seatHeight) {
                                                    if sets.indices.contains(1) { sets[1].seatHeight = sets[0].seatHeight }
                                                    if sets.indices.contains(2) { sets[2].seatHeight = sets[0].seatHeight }
                                                }
                                            }
                                        case .barHeight:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[0].barHeight.map(String.init) ?? "" },
                                                set: { sets[0].barHeight = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit { if enabledFields.contains(.barHeight) { schedulePropagation() } }
                                            .onSubmit {
                                                if enabledFields.contains(.barHeight) {
                                                    if sets.indices.contains(1) { sets[1].barHeight = sets[0].barHeight }
                                                    if sets.indices.contains(2) { sets[2].barHeight = sets[0].barHeight }
                                                }
                                            }
                                            .onChange(of: sets[0].barHeight) { _, _ in
                                                if enabledFields.contains(.barHeight) {
                                                    if sets.indices.contains(1) { sets[1].barHeight = sets[0].barHeight }
                                                    if sets.indices.contains(2) { sets[2].barHeight = sets[0].barHeight }
                                                }
                                            }
                                        case .seatAngle:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[0].seatAngle.map(String.init) ?? "" },
                                                set: { sets[0].seatAngle = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit { if enabledFields.contains(.seatAngle) { schedulePropagation() } }
                                            .onSubmit {
                                                if enabledFields.contains(.seatAngle) {
                                                    if sets.indices.contains(1) { sets[1].seatAngle = sets[0].seatAngle }
                                                    if sets.indices.contains(2) { sets[2].seatAngle = sets[0].seatAngle }
                                                }
                                            }
                                            .onChange(of: sets[0].seatAngle) { _, _ in
                                                if enabledFields.contains(.seatAngle) {
                                                    if sets.indices.contains(1) { sets[1].seatAngle = sets[0].seatAngle }
                                                    if sets.indices.contains(2) { sets[2].seatAngle = sets[0].seatAngle }
                                                }
                                            }
                                        case .footPlacement:
                                            TextField(field.placeholder, text: $sets[0].footPlacement)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled(true)
                                                .textFieldStyle(.roundedBorder)
                                                .onSubmit { if enabledFields.contains(.footPlacement) { schedulePropagation() } }
                                                .onChange(of: sets[0].footPlacement) { _, _ in
                                                    if enabledFields.contains(.footPlacement) {
                                                        if sets.indices.contains(1) { sets[1].footPlacement = sets[0].footPlacement }
                                                        if sets.indices.contains(2) { sets[2].footPlacement = sets[0].footPlacement }
                                                    }
                                                }
                                        case .lean:
                                            Toggle("", isOn: $sets[0].lean)
                                                .labelsHidden()
                                                .onChange(of: sets[0].lean) { _, _ in
                                                    if enabledFields.contains(.lean) {
                                                        if sets.indices.contains(1) { sets[1].lean = sets[0].lean }
                                                        if sets.indices.contains(2) { sets[2].lean = sets[0].lean }
                                                    }
                                                }
                                        case .cableHeight:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[0].cableHeight.map(String.init) ?? "" },
                                                set: { sets[0].cableHeight = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit { if enabledFields.contains(.cableHeight) { schedulePropagation() } }
                                            .onSubmit {
                                                if enabledFields.contains(.cableHeight) {
                                                    if sets.indices.contains(1) { sets[1].cableHeight = sets[0].cableHeight }
                                                    if sets.indices.contains(2) { sets[2].cableHeight = sets[0].cableHeight }
                                                }
                                            }
                                            .onChange(of: sets[0].cableHeight) { _, _ in
                                                if enabledFields.contains(.cableHeight) {
                                                    if sets.indices.contains(1) { sets[1].cableHeight = sets[0].cableHeight }
                                                    if sets.indices.contains(2) { sets[2].cableHeight = sets[0].cableHeight }
                                                }
                                            }
                                        case .myoReps:
                                            TextField(field.placeholder, text: $sets[0].myoReps)
                                                .keyboardType(.numbersAndPunctuation)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled(true)
                                                .textFieldStyle(.roundedBorder)
                                                .onSubmit { if enabledFields.contains(.myoReps) { schedulePropagation() } }
                                                .onSubmit {
                                                    if enabledFields.contains(.myoReps) {
                                                        if sets.indices.contains(1) { sets[1].myoReps = sets[0].myoReps }
                                                        if sets.indices.contains(2) { sets[2].myoReps = sets[0].myoReps }
                                                    }
                                                }
                                                .onChange(of: sets[0].myoReps) { _, _ in
                                                    if enabledFields.contains(.myoReps) {
                                                        if sets.indices.contains(1) { sets[1].myoReps = sets[0].myoReps }
                                                        if sets.indices.contains(2) { sets[2].myoReps = sets[0].myoReps }
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }

                        ForEach(sets.indices.dropFirst(), id: \.self) { idx in
                            HStack(spacing: 12) {
                                Text("Set \(sets[idx].setNumber)")
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading) {
                                    Text("Weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("kg", text: $sets[idx].weight)
                                        .keyboardType(.decimalPad)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: sets[idx].weight) { _, _ in
                                            if !isProgrammaticUpdate {
                                                var s = synced[idx] ?? SyncedFields()
                                                s.weight = false
                                                synced[idx] = s
                                            }
                                        }
                                }
                                VStack(alignment: .leading) {
                                    Text("Reps")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("reps", text: $sets[idx].reps)
                                        .keyboardType(enabledFields.contains(.myoReps) ? .numbersAndPunctuation : .numberPad)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: sets[idx].reps) { _, _ in
                                            if !isProgrammaticUpdate {
                                                var s = synced[idx] ?? SyncedFields()
                                                s.reps = false
                                                synced[idx] = s
                                            }
                                        }
                                }
                                ForEach(Array(enabledFields), id: \.self) { field in
                                    VStack(alignment: .leading) {
                                        Text(field.title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        switch field {
                                        case .seatHeight:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[idx].seatHeight.map(String.init) ?? "" },
                                                set: { sets[idx].seatHeight = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: sets[idx].seatHeight) { _, _ in
                                                if !isProgrammaticUpdate {
                                                    var s = synced[idx] ?? SyncedFields()
                                                    s.seatHeight = false
                                                    synced[idx] = s
                                                }
                                            }
                                        case .barHeight:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[idx].barHeight.map(String.init) ?? "" },
                                                set: { sets[idx].barHeight = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: sets[idx].barHeight) { _, _ in
                                                if !isProgrammaticUpdate {
                                                    var s = synced[idx] ?? SyncedFields()
                                                    s.barHeight = false
                                                    synced[idx] = s
                                                }
                                            }
                                        case .seatAngle:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[idx].seatAngle.map(String.init) ?? "" },
                                                set: { sets[idx].seatAngle = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: sets[idx].seatAngle) { _, _ in
                                                if !isProgrammaticUpdate {
                                                    var s = synced[idx] ?? SyncedFields()
                                                    s.seatAngle = false
                                                    synced[idx] = s
                                                }
                                            }
                                        case .footPlacement:
                                            TextField(field.placeholder, text: $sets[idx].footPlacement)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled(true)
                                                .textFieldStyle(.roundedBorder)
                                                .onChange(of: sets[idx].footPlacement) { _, _ in
                                                    if !isProgrammaticUpdate {
                                                        var s = synced[idx] ?? SyncedFields()
                                                        s.footPlacement = false
                                                        synced[idx] = s
                                                    }
                                                }
                                        case .lean:
                                            Toggle("", isOn: $sets[idx].lean)
                                                .labelsHidden()
                                                .onChange(of: sets[idx].lean) { _, _ in
                                                    if !isProgrammaticUpdate {
                                                        var s = synced[idx] ?? SyncedFields()
                                                        s.lean = false
                                                        synced[idx] = s
                                                    }
                                                }
                                        case .cableHeight:
                                            TextField(field.placeholder, text: Binding(
                                                get: { sets[idx].cableHeight.map(String.init) ?? "" },
                                                set: { sets[idx].cableHeight = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                            ))
                                            .keyboardType(.numberPad)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: sets[idx].cableHeight) { _, _ in
                                                if !isProgrammaticUpdate {
                                                    var s = synced[idx] ?? SyncedFields()
                                                    s.cableHeight = false
                                                    synced[idx] = s
                                                }
                                            }
                                        case .myoReps:
                                            TextField(field.placeholder, text: $sets[idx].myoReps)
                                                .keyboardType(.numbersAndPunctuation)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled(true)
                                                .textFieldStyle(.roundedBorder)
                                                .onChange(of: sets[idx].myoReps) { _, _ in
                                                    if !isProgrammaticUpdate {
                                                        var s = synced[idx] ?? SyncedFields()
                                                        s.myoReps = false
                                                        synced[idx] = s
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    let nonEmptySets = sets.filter { !$0.weight.isEmpty || !$0.reps.isEmpty }
                    var trimmedSets = nonEmptySets
                    for i in trimmedSets.indices {
                        if !enabledFields.contains(.seatHeight) { trimmedSets[i].seatHeight = nil }
                        if !enabledFields.contains(.barHeight) { trimmedSets[i].barHeight = nil }
                        if !enabledFields.contains(.seatAngle) { trimmedSets[i].seatAngle = nil }
                        if !enabledFields.contains(.footPlacement) { trimmedSets[i].footPlacement = "" }
                        if !enabledFields.contains(.lean) { trimmedSets[i].lean = false }
                        if !enabledFields.contains(.cableHeight) { trimmedSets[i].cableHeight = nil }
                        if !enabledFields.contains(.myoReps) { trimmedSets[i].myoReps = "" }
                    }
                    synced.removeAll()
                    onLog(trimmedSets)
                    dismiss()
                } label: {
                    Text("Log Exercise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!sets.contains { !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            }
        }
        .padding()
        .navigationTitle("Log Sets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            computeLastLogSummary()
            recomputeLatestWeight()
            computeBestAtLatestWeightSummary()
            for idx in 1...2 where sets.indices.contains(idx) {
                synced[idx] = SyncedFields()
            }
            DispatchQueue.main.async { propagateFromFirstSet() }
        }
        .onChange(of: enabledFields) { _, _ in
            schedulePropagation()
        }
        .onChange(of: sets) { _, _ in
            recomputeLatestWeight()
            computeBestAtLatestWeightSummary()
        }
    }

    private func recomputeLatestWeight() {
        let nonEmptyWeights = sets.compactMap { Double($0.weight.trimmingCharacters(in: .whitespacesAndNewlines)) }
        latestWeight = nonEmptyWeights.last
    }

    private func computeLastLogSummary() {
        let request: NSFetchRequest<ExerciseEntry> = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", exerciseName)
        request.sortDescriptors = [NSSortDescriptor(key: "workout.date", ascending: false)]
        request.fetchLimit = 1

        do {
            if let entry = try viewContext.fetch(request).first {
                let orderedSets = entry.setsArray
                print("LastLog: Fetched \(orderedSets.count) sets for \(exerciseName)")
                print("LastLog setNumbers: \(orderedSets.map { $0.setNumber })")

                let date = entry.workout?.date ?? Date()
                let dateString = date.formatted(date: .abbreviated, time: .omitted)
                if !orderedSets.isEmpty {
                    
                    let setLines = orderedSets.map { set -> String in
                        let weightString = String(format: "%.2f", set.weight)
                        var details: [String] = []
                        if let setID = set.id {
                            let stored = OptionalFieldsStore.shared.load(for: setID)
                            func appendIfPresent(_ key: String, label: String? = nil) {
                                if let value = stored[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    if let label = label { details.append("\(label): \(value)") } else { details.append(value) }
                                }
                            }
                            appendIfPresent("seatHeight", label: "Seat Height")
                            appendIfPresent("barHeight", label: "Bar Height")
                            appendIfPresent("seatAngle", label: "Seat Angle")
                            appendIfPresent("footPlacement", label: "Foot Placement")
                            appendIfPresent("lean", label: "Lean")
                            appendIfPresent("cableHeight", label: "Cable Height")
                            appendIfPresent("myoReps", label: "MyoReps")
                        }
                        let detailsSuffix = details.isEmpty ? "" : " [" + details.joined(separator: ", ") + "]"
                        return "Set \(set.setNumber): \(weightString) kg × \(set.reps)\(detailsSuffix)"
                    }
                    lastLogSummary = "Last time: \(dateString)\n" + setLines.joined(separator: "\n")
                } else {
                    lastLogSummary = "Last time: \(dateString) — no sets recorded"
                }
            } else {
                lastLogSummary = ""
            }
        } catch {
            print("Error fetching last log: \(error)")
            lastLogSummary = ""
        }
    }

    private func computeBestAtLatestWeightSummary() {
        let entryRequest: NSFetchRequest<ExerciseEntry> = ExerciseEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(format: "name == %@", exerciseName)
        entryRequest.sortDescriptors = [NSSortDescriptor(key: "workout.date", ascending: false)]

        do {
            let entries = try viewContext.fetch(entryRequest)
            var bestEntry: ExerciseEntry? = nil
            var bestFirstSetWeight: Double = -Double.infinity

            for entry in entries {
                let setRequest: NSFetchRequest<SetEntry> = SetEntry.fetchRequest()
                setRequest.predicate = NSPredicate(format: "exercise == %@", entry)
                setRequest.sortDescriptors = [NSSortDescriptor(key: "setNumber", ascending: true)]
                setRequest.fetchLimit = 0
                let sets = try viewContext.fetch(setRequest)
                if let first = sets.first {
                    if first.weight > bestFirstSetWeight {
                        bestFirstSetWeight = first.weight
                        bestEntry = entry
                    }
                }
            }

            if let entry = bestEntry {
                let sets = entry.setsArray
                let date = entry.workout?.date ?? Date()
                let dateString = date.formatted(date: .abbreviated, time: .omitted)

                print("BestAt: Fetched \(sets.count) sets for \(exerciseName) on \(dateString)")
                print("BestAt setNumbers: \(sets.map { $0.setNumber })")

                if !sets.isEmpty {
                    
                    let setLines = sets.map { set -> String in
                        let weightString = String(format: "%.2f", set.weight)
                        return "Set \(set.setNumber): \(weightString) kg × \(set.reps)"
                    }
                    bestAtWeightSummary = "Personal Best (heaviest first set): \(dateString)\n" + setLines.joined(separator: "\n")
                } else {
                    bestAtWeightSummary = "Personal Best: no sets recorded"
                }
            } else {
                bestAtWeightSummary = "Personal Best: no history yet"
            }
        } catch {
            print("Error computing personal best: \(error)")
            bestAtWeightSummary = ""
        }
    }

    private func propagateFromFirstSet() {
        guard sets.indices.contains(0) else { return }
        let first = sets[0]
        isProgrammaticUpdate = true
        defer { isProgrammaticUpdate = false }
        for idx in sets.indices.dropFirst() {
            let sync = synced[idx, default: SyncedFields()]
            if sync.weight, idx <= 2 {
                if sets[idx].weight != first.weight { sets[idx].weight = first.weight }
            }
            if sync.reps, idx <= 2 {
                if sets[idx].reps != first.reps { sets[idx].reps = first.reps }
            }
            if sync.seatHeight {
                if sets[idx].seatHeight != first.seatHeight { sets[idx].seatHeight = first.seatHeight }
            }
            if sync.barHeight {
                if sets[idx].barHeight != first.barHeight { sets[idx].barHeight = first.barHeight }
            }
            if sync.seatAngle {
                if sets[idx].seatAngle != first.seatAngle { sets[idx].seatAngle = first.seatAngle }
            }
            if sync.footPlacement {
                if sets[idx].footPlacement != first.footPlacement { sets[idx].footPlacement = first.footPlacement }
            }
            if sync.lean {
                if sets[idx].lean != first.lean { sets[idx].lean = first.lean }
            }
            if sync.cableHeight {
                if sets[idx].cableHeight != first.cableHeight { sets[idx].cableHeight = first.cableHeight }
            }
            if sync.myoReps {
                if sets[idx].myoReps != first.myoReps { sets[idx].myoReps = first.myoReps }
            }
            synced[idx] = sync
        }
    }
}

// MARK: - History View (reads from Core Data)

struct HistoryView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.date, ascending: false)]
    )
    private var workouts: FetchedResults<Workout>
    
    var body: some View {
        List {
            ForEach(workouts) { workout in
                VStack(alignment: .leading) {
                    Text("\(workout.sessionType ?? "Unknown") – \((workout.date ?? Date()).formatted(date: .abbreviated, time: .omitted))")
                        .font(.headline)
                    Text("\(workout.exercisesArray.count) exercise(s)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("History")
    }
}

extension Workout {
    var exercisesArray: [ExerciseEntry] {
        guard let context = self.managedObjectContext else { return [] }
        let request: NSFetchRequest<ExerciseEntry> = ExerciseEntry.fetchRequest()
        request.predicate = NSPredicate(format: "workout == %@", self)
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching exercises for workout \(String(describing: id)): \(error)")
            return []
        }
    }
}

extension ExerciseEntry {
    var setsArray: [SetEntry] {
        guard let context = self.managedObjectContext else { return [] }
        let request: NSFetchRequest<SetEntry> = SetEntry.fetchRequest()
        request.predicate = NSPredicate(format: "exercise == %@", self)
        request.sortDescriptors = [NSSortDescriptor(key: "setNumber", ascending: true)]
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching sets for exercise \(String(describing: id)): \(error)")
            return []
        }
    }
}

import SwiftUI
import CoreData

struct ExportDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var exportURL: URL?
    @State private var showShareSheet: Bool = false
    @State private var pendingAutoShare: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Export Workouts")
                    .font(.largeTitle)
                    .bold()
                
                Text("Select a date range to export your workout data as CSV.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                
                HStack {
                    Button("Last 7 Days") {
                        let cal = Calendar.current
                        endDate = Date()
                        startDate = cal.date(byAdding: .day, value: -6, to: endDate) ?? endDate
                        pendingAutoShare = true
                        if let url = generateCSV() {
                            exportURL = url
                            showShareSheet = true
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Last Month") {
                        let cal = Calendar.current
                        endDate = Date()
                        startDate = cal.date(byAdding: .month, value: -1, to: endDate) ?? endDate
                        pendingAutoShare = true
                        if let url = generateCSV() {
                            exportURL = url
                            showShareSheet = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button {
                    pendingAutoShare = true
                    if let url = generateCSV() {
                        exportURL = url
                        showShareSheet = true
                    }
                } label: {
                    Text("Generate & Share CSV")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .disabled(startDate > endDate)
            }
        }
        .padding()
        .navigationTitle("Export Data")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url]) { activityType, completed, returnedItems, activityError in
                    if completed {
                        dismiss()
                    }
                    pendingAutoShare = false
                }
            }
        }
    }
    
    private func generateCSV() -> URL? {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.date, ascending: true)]
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        
        do {
            let workouts = try viewContext.fetch(request)
            
            var includeCableHeight = false
            var setIDsToCableHeight: [UUID: String] = [:]
            for workout in workouts {
                let exerciseRequest: NSFetchRequest<ExerciseEntry> = ExerciseEntry.fetchRequest()
                exerciseRequest.predicate = NSPredicate(format: "workout == %@", workout)
                let exercisesForWorkout = (try? viewContext.fetch(exerciseRequest)) ?? []

                for exercise in exercisesForWorkout {
                    let setRequest: NSFetchRequest<SetEntry> = SetEntry.fetchRequest()
                    setRequest.predicate = NSPredicate(format: "exercise == %@", exercise)
                    let setsForExercise = (try? viewContext.fetch(setRequest)) ?? []

                    for set in setsForExercise {
                        if let setID = set.id {
                            let stored = OptionalFieldsStore.shared.load(for: setID)
                            if let ch = stored["cableHeight"], !ch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                includeCableHeight = true
                                setIDsToCableHeight[setID] = ch
                            }
                        }
                    }
                }
            }
            print("Export includeCableHeight=\(includeCableHeight), total setIDs with cableHeight=\(setIDsToCableHeight.count)")
            
            var csv = includeCableHeight ? "date,sessionType,exerciseName,setNumber,weight,reps,cableHeight\n" : "date,sessionType,exerciseName,setNumber,weight,reps\n"
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            
            for workout in workouts {
                guard let date = workout.date else { continue }
                let dateString = formatter.string(from: date)

                let exerciseRequest: NSFetchRequest<ExerciseEntry> = ExerciseEntry.fetchRequest()
                exerciseRequest.predicate = NSPredicate(format: "workout == %@", workout)
                exerciseRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]

                let exercisesForWorkout = (try? viewContext.fetch(exerciseRequest)) ?? []

                print("Export: workout \(workout.id?.uuidString ?? "<no id>") has \(exercisesForWorkout.count) exercise(s)")

                for exercise in exercisesForWorkout {
                    let setRequest: NSFetchRequest<SetEntry> = SetEntry.fetchRequest()
                    setRequest.predicate = NSPredicate(format: "exercise == %@", exercise)
                    setRequest.sortDescriptors = [NSSortDescriptor(key: "setNumber", ascending: true)]

                    let setsForExercise = (try? viewContext.fetch(setRequest)) ?? []

                    for set in setsForExercise {
                        if let setID = set.id, includeCableHeight, let ch = setIDsToCableHeight[setID] {
                            let line = "\(dateString),\(workout.sessionType ?? ""),\(exercise.name ?? ""),\(set.setNumber),\(set.weight),\(set.reps),\(ch)\n"
                            csv.append(line)
                        } else {
                            let line = "\(dateString),\(workout.sessionType ?? ""),\(exercise.name ?? ""),\(set.setNumber),\(set.weight),\(set.reps)\n"
                            csv.append(line)
                        }
                    }
                }
            }
            
            let filename = "workouts_\(formatter.string(from: startDate))_to_\(formatter.string(from: endDate)).csv"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Error exporting CSV: \(error)")
            return nil
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var completion: UIActivityViewController.CompletionWithItemsHandler?

    init(activityItems: [Any], completion: UIActivityViewController.CompletionWithItemsHandler? = nil) {
        self.activityItems = activityItems
        self.completion = completion
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = completion
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let model = NSManagedObjectModel.mergedModel(from: [Bundle.main]) ?? NSManagedObjectModel()
    let container = NSPersistentContainer(name: "Preview", managedObjectModel: model)
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Failed to load in-memory store: \(error)")
        }
    }
    let context = container.viewContext
    return ContentView()
        .environment(\.managedObjectContext, context)
}
