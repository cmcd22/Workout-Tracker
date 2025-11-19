import SwiftUI
import CoreData

// MARK: - Simple in-memory models for the current workout screen

struct LoggedSet: Identifiable {
    let id = UUID()
    var setNumber: Int
    var weight: String
    var reps: String
}

struct LoggedExercise: Identifiable {
    let id = UUID()
    var name: String
    var sets: [LoggedSet]
}

// MARK: - Session Types

let sessionTypes: [String] = [
    "Push",
    "Pull",
    "Legs",
    "Upper",
    "Lower",
    "Full Body",
    "Cardio"
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
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
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
            .padding()
            .navigationTitle("Gym Tracker")
        }
    }
}

// MARK: - Add Workout Screen

struct AddWorkoutView: View {
    private let workoutDate = Date()
    
    var body: some View {
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
        .padding()
        .navigationTitle("Add Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise Selection Screen

struct ExerciseSelectionView: View {
    let sessionType: String
    let workoutDate: Date
    
    @State private var loggedExercises: [LoggedExercise] = []
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var exercises: [String] {
        ExercisePresets.exercisesBySessionType[sessionType] ??
        [
            "Exercise 1",
            "Exercise 2",
            "Exercise 3",
            "Exercise 4",
            "Exercise 5",
            "Exercise 6"
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("\(sessionType) Session")
                .font(.largeTitle)
                .bold()
            
            Text("Date: \(workoutDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
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
            
            if !loggedExercises.isEmpty {
                Divider()
                Text("Logged so far:")
                    .font(.headline)
                ForEach(loggedExercises) { exercise in
                    Text("• \(exercise.name) – \(exercise.sets.count) set(s)")
                        .font(.subheadline)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    print("Add New Exercise tapped")
                } label: {
                    Text("Add New")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    print("Search tapped")
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
            }
        }
        .padding()
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func finishWorkout() {
        let nonEmptyExercises = loggedExercises.filter { !$0.sets.isEmpty }
        guard !nonEmptyExercises.isEmpty else {
            dismiss()
            return
        }
        
        let workout = Workout(context: viewContext)
        workout.id = UUID()
        workout.date = workoutDate
        workout.sessionType = sessionType
        
        for (index, loggedExercise) in nonEmptyExercises.enumerated() {
            let exercise = ExerciseEntry(context: viewContext)
            exercise.id = UUID()
            exercise.name = loggedExercise.name
            exercise.order = Int16(index)
            exercise.workout = workout
            
            for loggedSet in loggedExercise.sets {
                let setEntry = SetEntry(context: viewContext)
                setEntry.id = UUID()
                setEntry.setNumber = Int16(loggedSet.setNumber)
                setEntry.weight = Double(loggedSet.weight) ?? 0.0
                setEntry.reps = Int16(Int(loggedSet.reps) ?? 0)
                setEntry.exercise = exercise
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving workout: \(error)")
        }
        
        dismiss()
    }
}

// MARK: - Exercise Detail (Sets Entry)

struct ExerciseDetailView: View {
    let exerciseName: String
    let onLog: ([LoggedSet]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sets: [LoggedSet] = (1...5).map {
        LoggedSet(setNumber: $0, weight: "", reps: "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exerciseName)
                .font(.largeTitle)
                .bold()
            
            Text("Enter weight and reps for each set.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($sets) { $set in
                        HStack(spacing: 12) {
                            Text("Set \(set.setNumber)")
                                .frame(width: 60, alignment: .leading)
                            
                            VStack(alignment: .leading) {
                                Text("Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("kg", text: $set.weight)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Reps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("reps", text: $set.reps)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical)
            }
            
            Spacer()
            
            Button {
                let nonEmptySets = sets.filter { !$0.weight.isEmpty || !$0.reps.isEmpty }
                onLog(nonEmptySets)
                dismiss()
            } label: {
                Text("Log Exercise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .bold()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Log Sets")
        .navigationBarTitleDisplayMode(.inline)
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
                    Text("\(workout.sessionType) – \((workout.date ?? Date()).formatted(date: .abbreviated, time: .omitted))")
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

// Helper to turn NSSet? into [ExerciseEntry]
extension Workout {
    var exercisesArray: [ExerciseEntry] {
        let set = exercises as? Set<ExerciseEntry> ?? []
        return set.sorted { $0.order < $1.order }
    }
}

import SwiftUI
import CoreData

struct ExportDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var exportURL: URL?
    @State private var showShareSheet: Bool = false
    
    var body: some View {
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
            
            Spacer()
            
            Button {
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
        .padding()
        .navigationTitle("Export Data")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
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
            
            var csv = "date,sessionType,exerciseName,setNumber,weight,reps\n"
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            
            for workout in workouts {
                guard let date = workout.date else { continue }
                
                let dateString = formatter.string(from: date)
                
                for exercise in workout.exercisesArray {
                    let sets = exercise.sets as? Set<SetEntry> ?? []
                    for set in sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                        let line = "\(dateString),\(workout.sessionType),\(exercise.name),\(set.setNumber),\(set.weight),\(set.reps)\n"
                        csv.append(line)
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

// Simple UIActivityViewController wrapper for sharing
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
