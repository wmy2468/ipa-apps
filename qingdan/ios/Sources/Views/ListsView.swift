import SwiftUI

struct ListsView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false
    @State private var showQuick = false
    @State private var newName = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(store.lists) { list in
                    NavigationLink(destination: ListDetailView(listID: list.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name).font(.headline)
                                Text("\(list.openCount) 个未完成")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .onDelete { idx in
                    idx.forEach { store.deleteList(store.lists[$0].id) }
                }
            }
            .navigationTitle("清单")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showQuick = true } label: { Image(systemName: "wand.and.stars") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newName = ""
                        showAdd = true
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showQuick) {
                QuickAddView().environmentObject(store)
            }
            .sheet(isPresented: $showAdd) {
                NavigationView {
                    Form { TextField("清单名", text: $newName) }
                        .navigationTitle("新建清单")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { showAdd = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("创建") {
                                    store.addList(newName)
                                    showAdd = false
                                }
                            }
                        }
                }
            }
        }
    }
}

struct ListDetailView: View {
    @EnvironmentObject var store: Store
    let listID: UUID

    @State private var editing: Task?
    @State private var showAdd = false

    private var list: TodoList? { store.lists.first { $0.id == listID } }

    var body: some View {
        List {
            if let list = list {
                ForEach(list.tasks) { task in
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            store.toggleTask(listID: listID, taskID: task.id)
                        } label: {
                            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.done ? .blue : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .strikethrough(task.done)
                                .foregroundColor(task.done ? .secondary : .primary)
                            HStack(spacing: 8) {
                                if let due = task.dueAt {
                                    Text(dueText(due, overdue: task.isOverdue))
                                        .font(.caption)
                                        .foregroundColor(task.isOverdue ? .red : .secondary)
                                }
                                if task.repeatRule != .none {
                                    Text(task.repeatRule.label)
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            if !task.note.isEmpty {
                                Text(task.note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = task }
                }
                .onDelete { idx in
                    idx.forEach { store.deleteTask(listID: listID, taskID: list.tasks[$0].id) }
                }
            }
        }
        .navigationTitle(list?.name ?? "清单")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            if let list = list {
                TaskEditor(listID: list.id, task: nil)
                    .environmentObject(store)
            }
        }
        .sheet(item: $editing) { task in
            TaskEditor(listID: listID, task: task)
                .environmentObject(store)
        }
    }

    private func dueText(_ d: Date, overdue: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return (overdue ? "已过 " : "") + f.string(from: d)
    }
}

struct TaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.presentationMode) var presentation

    let listID: UUID
    let task: Task?

    @State private var title = ""
    @State private var note = ""
    @State private var useDue = true
    @State private var due = Date().addingTimeInterval(3600)
    @State private var repeatRule: RepeatRule = .none

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("要做什么", text: $title)
                    TextField("备注（可选）", text: $note)
                }
                Section {
                    Toggle("设置截止时间", isOn: $useDue)
                    if useDue {
                        DatePicker("时间", selection: $due, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section {
                    Picker("重复", selection: $repeatRule) {
                        ForEach(RepeatRule.allCases, id: \.self) { r in
                            Text(r.label).tag(r)
                        }
                    }
                }
                if task == nil {
                    Section {
                        Text("勾掉后会自动生成下一期（仅重复任务）")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(task == nil ? "新任务" : "编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentation.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: fill)
        }
    }

    private func fill() {
        guard let t = task else { return }
        title = t.title
        note = t.note
        repeatRule = t.repeatRule
        if let d = t.dueAt {
            useDue = true
            due = d
        } else {
            useDue = false
        }
    }

    private func save() {
        let dueAt = useDue ? due : nil
        if let t = task {
            store.updateTask(listID: listID, taskID: t.id, title: title, note: note,
                             dueAt: dueAt, repeatRule: repeatRule)
        } else {
            store.addTask(listID: listID, title: title, dueAt: dueAt, note: note, repeatRule: repeatRule)
        }
        presentation.wrappedValue.dismiss()
    }
}
