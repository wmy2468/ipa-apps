import SwiftUI

struct CouponsView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                if store.coupons.isEmpty {
                    Text("还没有券。把快到期的券加进来，到期前会提醒你。")
                        .foregroundColor(.secondary)
                }
                ForEach(sorted) { c in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.title)
                            Text(sub(c)).font(.caption).foregroundColor(color(c))
                        }
                        Spacer()
                    }
                }
                .onDelete { idx in
                    idx.forEach { store.deleteCoupon(sorted[$0].id) }
                }
            }
            .navigationTitle("优惠券")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd) {
                CouponEditor()
                    .environmentObject(store)
            }
        }
    }

    private var sorted: [Coupon] {
        store.coupons.sorted { $0.expireAt < $1.expireAt }
    }

    private func sub(_ c: Coupon) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        let base = f.string(from: c.expireAt)
        if c.daysLeft < 0 { return "已过期 · \(base)" }
        if c.daysLeft == 0 { return "今天到期 · \(base)" }
        return "还有 \(c.daysLeft) 天 · \(base)"
    }

    private func color(_ c: Coupon) -> Color {
        if c.daysLeft < 0 { return .secondary }
        if c.daysLeft <= 3 { return .red }
        if c.daysLeft <= 7 { return .orange }
        return .secondary
    }
}

struct CouponEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.presentationMode) var presentation

    @State private var title = ""
    @State private var expire = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        NavigationView {
            Form {
                Section { TextField("券名，比如 盒马 50 元券", text: $title) }
                Section {
                    DatePicker("到期日", selection: $expire, displayedComponents: [.date])
                }
                Section {
                    Text("到期前会按「提前提醒」的设置每天 9 点、20 点提醒一次。")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加券")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentation.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.addCoupon(title, expireAt: expire)
                        presentation.wrappedValue.dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
