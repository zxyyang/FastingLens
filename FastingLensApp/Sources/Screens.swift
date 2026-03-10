import AppFeatures
import Charts
import PhotosUI
import SwiftUI
import UIKit

private enum MealImageUploadOptimizer {
    static let maxDimension: CGFloat = 1280
    static let maxUploadBytes = 450 * 1024
    static let compressionQualities: [CGFloat] = [0.82, 0.68, 0.54, 0.4, 0.28, 0.18]

    static func prepareUploadData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return prepareUploadData(from: image)
    }

    static func prepareUploadData(from image: UIImage) -> Data? {
        let resizedImage = resizedImageIfNeeded(from: image)
        var fallbackData: Data?

        for quality in compressionQualities {
            guard let data = resizedImage.jpegData(compressionQuality: quality) else { continue }
            fallbackData = data
            if data.count <= maxUploadBytes {
                return data
            }
        }

        return fallbackData
    }

    private static func resizedImageIfNeeded(from image: UIImage) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private enum AppTab: Hashable {
    case today
    case assistant
    case data
    case profile
}

private struct LocalChatBubble: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct ActionPill: View {
    let title: String
    let color: Color
    let textColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(textColor)
    }
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayScreen()
                .tabItem {
                    Label("今天", systemImage: "house.fill")
                }
                .tag(AppTab.today)

            AssistantScreen()
                .tabItem {
                    Label("助手", systemImage: "bubble.left.and.text.bubble.right.fill")
                }
                .tag(AppTab.assistant)

            DataScreen()
                .tabItem {
                    Label("数据", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.data)

            ProfileScreen()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(FastingLensTheme.flame)
        .preferredColorScheme(.light)
    }
}

private struct TodayScreen: View {
    @Environment(AppState.self) private var appState
    @State private var showMealSheet = false
    @State private var showWaterSheet = false
    @State private var showWeightSheet = false

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: .now)
    }

    private var effectiveTDEE: Int {
        appState.healthKit.isAuthorized && appState.healthKit.estimatedTDEE > 0
            ? appState.healthKit.estimatedTDEE
            : appState.persisted.settings.dailyCalorieGoal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greetingHeader
                    metricGrid
                    compactFastingRing
                    quickActionRow
                    aiAdviceCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("首页")
            .sheet(isPresented: $showMealSheet) { MealQuickInputSheet() }
            .sheet(isPresented: $showWaterSheet) { WaterQuickInputSheet() }
            .sheet(isPresented: $showWeightSheet) { WeightQuickInputSheet() }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText)，\(appState.persisted.settings.displayName)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(FastingLensTheme.ink)
                Text(dateText)
                    .font(.fastingLabel)
                    .foregroundStyle(FastingLensTheme.slate)
            }
            Spacer()
        }
    }

    // MARK: - Calorie & Metric Dashboard

    private var remainingCalories: Int {
        max(appState.persisted.settings.dailyCalorieGoal - appState.todayCalories + appState.healthKit.todayActiveCalories, 0)
    }

    private var metricGrid: some View {
        VStack(spacing: 14) {
            // Main calorie card
            calorieOverviewCard

            // Bottom row: water + weight
            HStack(spacing: 14) {
                MetricGridCard(
                    title: "饮水",
                    value: "\(appState.todayWaterML)",
                    unit: "ml",
                    icon: "drop.fill",
                    tint: FastingLensTheme.mint,
                    bgColors: [FastingLensTheme.mint.opacity(0.1), FastingLensTheme.mint.opacity(0.04)]
                )

                MetricGridCard(
                    title: "体重",
                    value: appState.currentWeight.formatted(.number.precision(.fractionLength(1))),
                    unit: "kg",
                    icon: "scalemass.fill",
                    tint: FastingLensTheme.lemon,
                    bgColors: [FastingLensTheme.lemon.opacity(0.12), FastingLensTheme.lemon.opacity(0.04)]
                )
            }
        }
    }

    private var calorieOverviewCard: some View {
        let budget = appState.persisted.settings.dailyCalorieGoal
        let intake = appState.todayCalories
        let exercise = appState.healthKit.todayActiveCalories
        let remaining = max(budget - intake + exercise, 0)
        let progress = Double(intake) / Double(max(budget, 1))

        return VStack(spacing: 16) {
            // Top: intake | ring | exercise
            HStack {
                // Left: intake
                VStack(spacing: 4) {
                    Text("🍽️")
                        .font(.title2)
                    Text("饮食摄入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FastingLensTheme.ink.opacity(0.6))
                    Text("\(intake)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FastingLensTheme.ink)
                    Text("千卡")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FastingLensTheme.ink.opacity(0.5))
                }
                .frame(maxWidth: .infinity)

                // Center: ring with remaining
                ZStack {
                    Circle()
                        .stroke(FastingLensTheme.cloud, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(
                            progress > 1.0 ? FastingLensTheme.coral : FastingLensTheme.flame,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("还可以吃")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FastingLensTheme.ink.opacity(0.7))
                        Text("\(remaining)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(FastingLensTheme.flame)
                        Text("推荐摄入\(budget)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FastingLensTheme.ink.opacity(0.45))
                    }
                }
                .frame(width: 120, height: 120)

                // Right: exercise
                VStack(spacing: 4) {
                    Text("🏋️")
                        .font(.title2)
                    Text("运动消耗")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FastingLensTheme.ink.opacity(0.6))
                    Text("\(exercise)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FastingLensTheme.ink)
                    Text("千卡")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FastingLensTheme.ink.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }

            // Formula bar
            HStack(spacing: 0) {
                formulaItem(label: "还可以吃(千卡)", value: "\(remaining)", bold: true)
                formulaOp("=")
                formulaItem(label: "预算", value: "\(budget)", bold: false)
                formulaOp("-")
                formulaItem(label: "饮食", value: "\(intake)", bold: false)
                formulaOp("+")
                formulaItem(label: "运动", value: "\(exercise)", bold: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(FastingLensTheme.flame.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .softShadow()
    }

    private func formulaItem(label: String, value: String, bold: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FastingLensTheme.ink.opacity(0.55))
            Text(value)
                .font(.system(size: bold ? 20 : 16, weight: bold ? .heavy : .bold, design: .rounded))
                .foregroundStyle(bold ? FastingLensTheme.flame : FastingLensTheme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func formulaOp(_ op: String) -> some View {
        Text(op)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(FastingLensTheme.ink.opacity(0.4))
    }

    // MARK: - Compact Fasting Ring

    private var compactFastingRing: some View {
        let snapshot = appState.dashboardSnapshot
        let isFasting = snapshot.phase == .fasting
        let totalHours = isFasting ? appState.persisted.plan.fastingHours : appState.persisted.plan.eatingHours
        let totalSeconds = max(Double(totalHours * 3600), 1)
        let remaining = max(snapshot.phaseEndsAt.timeIntervalSince(.now), 0)
        let progress = min(max(1 - (remaining / totalSeconds), 0), 1)
        let accentColor = isFasting ? FastingLensTheme.flame : FastingLensTheme.mint

        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(FastingLensTheme.cloud.opacity(0.5), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: isFasting ? [FastingLensTheme.lemon, FastingLensTheme.flame] : [FastingLensTheme.mint, FastingLensTheme.lemon],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accentColor.opacity(0.3), radius: 8)
                Text(snapshot.phaseEndsAt, style: .timer)
                    .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 8) {
                Text(isFasting ? "🔥 断食中" : "🍽️ 进食窗口")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12), in: Capsule())

                Text(isFasting ? "保持燃脂节奏" : "把握进食窗口")
                    .font(.fastingBody)
                    .foregroundStyle(FastingLensTheme.slate)

                Text("第 \(appState.joinedDays) 天")
                    .font(.fastingLabel)
                    .foregroundStyle(accentColor)
            }

            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: isFasting
                    ? [FastingLensTheme.lemon.opacity(0.2), FastingLensTheme.flame.opacity(0.08)]
                    : [FastingLensTheme.mint.opacity(0.15), FastingLensTheme.lemon.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerL, style: .continuous)
        )
        .cardShadow()
    }

    // MARK: - Quick Actions

    private var quickActionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷记录")
                .font(.fastingSection)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(title: "记一餐", symbol: "fork.knife", tint: FastingLensTheme.flame) {
                    showMealSheet = true
                }
                QuickActionButton(title: "记饮水", symbol: "drop.fill", tint: FastingLensTheme.mint) {
                    showWaterSheet = true
                }
                QuickActionButton(title: "记体重", symbol: "scalemass.fill", tint: FastingLensTheme.lemon) {
                    showWeightSheet = true
                }
            }
        }
    }

    // MARK: - AI Advice Card

    private var aiAdviceCard: some View {
        let isFasting = appState.dashboardSnapshot.phase == .fasting
        let calorieRatio = Double(appState.todayCalories) / Double(max(appState.persisted.settings.dailyCalorieGoal, 1))
        let advice: (String, String) = {
            if isFasting && calorieRatio < 0.3 {
                return ("💪", "断食进行中，保持住！身体正在燃烧脂肪，多喝水帮助代谢。")
            } else if calorieRatio > 1.0 {
                return ("⚠️", "今天热量已超标，建议接下来选择轻食，多喝水，明天加油！")
            } else if calorieRatio > 0.8 {
                return ("🍃", "已接近今日热量上限，剩余餐次建议选低卡食物，如蔬菜沙拉。")
            } else if !isFasting && calorieRatio < 0.5 {
                return ("🥗", "进食窗口中热量还很充裕，记得均衡搭配蛋白质和蔬菜。")
            } else {
                return ("✨", "目前状态不错！距离目标体重 \(appState.persisted.settings.targetWeight.formatted(.number.precision(.fractionLength(1)))) kg 继续努力！")
            }
        }()

        return HStack(spacing: 12) {
            Text(advice.0)
                .font(.system(size: 28))

            Text(advice.1)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(FastingLensTheme.ink.opacity(0.8))
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [FastingLensTheme.flame.opacity(0.08), FastingLensTheme.lemon.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous)
        )
    }
}

// MARK: - Metric Grid Card

private struct MetricGridCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let tint: Color
    let bgColors: [Color]
    var isHighlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.fastingLabel)
                    .foregroundStyle(FastingLensTheme.slate)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(isHighlight ? FastingLensTheme.ink : FastingLensTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.fastingCaption)
                    .foregroundStyle(FastingLensTheme.slate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerGrid, style: .continuous)
        )
        .softShadow()
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint, in: Circle())
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(FastingLensTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
            .softShadow()
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Quick Input Sheets

private struct MealQuickInputSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var foodName = ""
    @State private var calories = ""
    @State private var mealType = "正餐"
    private let mealTypes = ["早餐", "午餐", "晚餐", "加餐", "放纵餐"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("食物名称")
                        .font(.fastingLabel)
                        .foregroundStyle(FastingLensTheme.slate)
                    TextField("如：一碗牛肉面", text: $foodName)
                        .padding(14)
                        .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("热量 (kcal)")
                        .font(.fastingLabel)
                        .foregroundStyle(FastingLensTheme.slate)
                    TextField("预估热量", text: $calories)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("餐次")
                        .font(.fastingLabel)
                        .foregroundStyle(FastingLensTheme.slate)
                    Picker("餐次", selection: $mealType) {
                        ForEach(mealTypes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                Button {
                    let cal = Int(calories) ?? 0
                    let meal = StoredMealRecord(
                        loggedAt: .now,
                        mealType: mealType,
                        totalCalories: cal,
                        notes: foodName,
                        items: [StoredMealItem(name: foodName, portion: "", estimatedCalories: cal)]
                    )
                    appState.addMeal(meal)
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FastingLensTheme.flameGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                }
                .disabled(foodName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
            .navigationTitle("🍜 记一餐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct WaterQuickInputSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var customML = ""
    private let presets = [250, 500, 750]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                let progress = min(Double(appState.todayWaterML) / Double(max(appState.persisted.settings.dailyWaterGoal, 1)), 1)
                VStack(spacing: 8) {
                    Text("\(appState.todayWaterML) / \(appState.persisted.settings.dailyWaterGoal) ml")
                        .font(.fastingDigits)
                        .foregroundStyle(FastingLensTheme.mint)
                    ProgressView(value: progress)
                        .tint(FastingLensTheme.mint)
                }

                Text("快速添加")
                    .font(.fastingLabel)
                    .foregroundStyle(FastingLensTheme.slate)

                HStack(spacing: 14) {
                    ForEach(presets, id: \.self) { ml in
                        Button {
                            appState.recordWater(ml: ml)
                            dismiss()
                        } label: {
                            Text("\(ml) ml")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FastingLensTheme.mintGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }

                HStack(spacing: 12) {
                    TextField("自定义 ml", text: $customML)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        if let ml = Int(customML), ml > 0 {
                            appState.recordWater(ml: ml)
                            dismiss()
                        }
                    } label: {
                        Text("记录")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(FastingLensTheme.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("💧 记饮水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct WeightQuickInputSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("上次记录")
                        .font(.fastingLabel)
                        .foregroundStyle(FastingLensTheme.slate)
                    Text("\(appState.currentWeight.formatted(.number.precision(.fractionLength(1)))) kg")
                        .font(.fastingDigits)
                        .foregroundStyle(FastingLensTheme.lemon)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("今日体重 (kg)")
                        .font(.fastingLabel)
                        .foregroundStyle(FastingLensTheme.slate)
                    TextField("如：62.5", text: $weightText)
                        .keyboardType(.decimalPad)
                        .padding(14)
                        .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer()

                Button {
                    if let w = Double(weightText) {
                        appState.recordWeight(w)
                        dismiss()
                    }
                } label: {
                    Text("保存")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FastingLensTheme.lemonGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                }
                .disabled(Double(weightText) == nil)
            }
            .padding(20)
            .navigationTitle("⚖️ 记体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct AssistantScreen: View {
    @Environment(AppState.self) private var appState
    @State private var composer = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var originalImageData: Data?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingSessions = false
    @State private var editableMealType = ""
    @State private var editableCalories = ""
    @State private var editableNotes = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(appState.activeChatMessages) { bubble in
                                ChatBubbleView(bubble: bubble)
                                    .id(bubble.id)
                            }

                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }

                            if let result = appState.latestRecognition {
                                ToolResultCard(
                                    result: result,
                                    editableMealType: $editableMealType,
                                    editableCalories: $editableCalories,
                                    editableNotes: $editableNotes,
                                    onConfirm: {
                                        appState.commitRecognition(makeEditedResult(from: result), imageData: originalImageData)
                                        appState.appendAssistantNote("已确认并保存这次餐食记录。")
                                        clearRecognitionDraft()
                                    },
                                    onReset: {
                                        appState.resetLatestRecognition()
                                        clearRecognitionDraft()
                                    }
                                )
                            }

                            if let error = appState.assistantErrorMessage {
                                Text(error)
                                    .font(.fastingLabel)
                                    .foregroundStyle(FastingLensTheme.coral)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if appState.isAssistantResponding {
                                if appState.assistantStreamingText.isEmpty {
                                    ChatLoadingRow()
                                } else {
                                    ChatStreamingRow(text: appState.assistantStreamingText)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: appState.activeChatMessages.count) { _, _ in
                        if let id = appState.activeChatMessages.last?.id {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                }

                assistantInputBar
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle(appState.persisted.settings.assistantName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("历史") {
                        showingSessions = true
                    }
                    .font(.fastingLabel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("新对话") {
                        appState.startNewChatSession()
                        clearRecognitionDraft()
                    }
                    .font(.fastingLabel)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingSessions) {
                AssistantSessionListSheet(isPresented: $showingSessions)
            }
            .task(id: selectedItem) {
                guard let selectedItem else { return }
                if let data = try? await selectedItem.loadTransferable(type: Data.self) {
                    originalImageData = data
                    selectedImage = UIImage(data: data)
                    selectedImageData = MealImageUploadOptimizer.prepareUploadData(from: data)
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                guard let newValue, let rawData = newValue.jpegData(compressionQuality: 0.92) else { return }
                originalImageData = rawData
                selectedImageData = MealImageUploadOptimizer.prepareUploadData(from: newValue)
            }
            .onChange(of: appState.latestRecognition?.mealType) { _, _ in
                syncEditableFields()
            }
        }
    }

    private var assistantInputBar: some View {
        VStack(spacing: 10) {
            if selectedImageData != nil {
                Button {
                    guard let uploadImageData = selectedImageData else { return }
                    let prompt = composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请帮我识别并记录这张餐食图片。" : composer
                    composer = ""
                    let originalData = originalImageData
                    Task { await appState.sendAssistantMessage(text: prompt, imageData: originalData ?? uploadImageData) }
                    selectedImageData = nil
                    originalImageData = nil
                    selectedImage = nil
                    selectedItem = nil
                } label: {
                    Text(appState.isAssistantResponding ? "处理中..." : "📸 发送给 AI 识别")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FastingLensTheme.flameGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                }
                .disabled(appState.isAssistantResponding)
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FastingLensTheme.flame)
                        .frame(width: 36, height: 36)
                        .background(FastingLensTheme.cloud.opacity(0.5), in: Circle())
                }

                Button {
                    showingCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FastingLensTheme.flame)
                        .frame(width: 36, height: 36)
                        .background(FastingLensTheme.cloud.opacity(0.5), in: Circle())
                }

                TextField("告诉我你吃了什么...", text: $composer)
                    .font(.fastingBody)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(FastingLensTheme.cloud.opacity(0.4), in: Capsule())

                Button {
                    sendComposerText()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            (composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isAssistantResponding)
                                ? AnyShapeStyle(FastingLensTheme.cloud)
                                : AnyShapeStyle(FastingLensTheme.flameGradient),
                            in: Circle()
                        )
                }
                .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isAssistantResponding)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            FastingLensTheme.snow
                .shadow(.drop(color: FastingLensTheme.ink.opacity(0.06), radius: 8, y: -2))
        )
    }

    private func sendComposerText() {
        let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composer = ""
        let imageToSend = selectedImageData ?? originalImageData
        selectedImageData = nil
        originalImageData = nil
        selectedImage = nil
        selectedItem = nil
        Task { await appState.sendAssistantMessage(text: text, imageData: imageToSend) }
    }

    private func syncEditableFields() {
        guard let result = appState.latestRecognition else { return }
        editableMealType = result.mealType.isEmpty ? appState.persisted.settings.defaultMealType : result.mealType
        editableCalories = String(result.estimatedTotalCalories)
        editableNotes = result.notes
    }

    private func makeEditedResult(from result: MealRecognitionResult) -> MealRecognitionResult {
        MealRecognitionResult(
            mealType: editableMealType.isEmpty ? result.mealType : editableMealType,
            foodItems: result.foodItems,
            estimatedTotalCalories: Int(editableCalories) ?? result.estimatedTotalCalories,
            confidence: result.confidence,
            notes: editableNotes
        )
    }

    private func clearRecognitionDraft() {
        originalImageData = nil
        selectedImageData = nil
        selectedImage = nil
        editableMealType = ""
        editableCalories = ""
        editableNotes = ""
        appState.resetLatestRecognition()
    }
}

private struct ChatBubbleView: View {
    @Environment(AppState.self) private var appState
    let bubble: StoredChatMessage

    var body: some View {
        if bubble.role == .system {
            systemBubble
        } else {
            HStack {
                if bubble.role != .user {
                    assistantBubble
                    Spacer(minLength: 40)
                } else {
                    Spacer(minLength: 40)
                    userBubble
                }
            }
        }
    }

    private var systemBubble: some View {
        Text(bubble.content)
            .font(.fastingCaption)
            .foregroundStyle(FastingLensTheme.slate)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(FastingLensTheme.cloud.opacity(0.5), in: Capsule())
            .frame(maxWidth: .infinity)
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .leading, spacing: 10) {
                bubbleImage
                Text(bubble.content)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                if let toolResult = bubble.toolResult {
                    ToolResultSummaryView(toolResult: toolResult)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.76, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [FastingLensTheme.flame, FastingLensTheme.lemon],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )

            Text(bubble.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.fastingCaption)
                .foregroundStyle(FastingLensTheme.slate.opacity(0.6))
                .padding(.trailing, 6)
        }
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(FastingLensTheme.flame, in: Circle())

                VStack(alignment: .leading, spacing: 10) {
                    bubbleImage
                    Text(bubble.content)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(FastingLensTheme.ink)
                        .lineSpacing(4)
                    if let toolResult = bubble.toolResult {
                        ToolResultSummaryView(toolResult: toolResult)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.74, alignment: .leading)
                .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(FastingLensTheme.cloud.opacity(0.6), lineWidth: 0.5)
                )
                .softShadow()
            }

            Text(bubble.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.fastingCaption)
                .foregroundStyle(FastingLensTheme.slate.opacity(0.6))
                .padding(.leading, 38)
        }
    }

    @ViewBuilder
    private var bubbleImage: some View {
        if let imageFileName = bubble.imageFileName,
           let image = UIImage(contentsOfFile: appState.imageURL(for: imageFileName).path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct ToolResultSummaryView: View {
    let toolResult: StoredToolResult

    private var parsedObject: [String: Any] {
        guard let data = toolResult.resultJSONString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(toolAccent)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(toolEmoji) \(toolTitle)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(FastingLensTheme.ink)

                ForEach(parsedLines, id: \.0) { line in
                    HStack {
                        Text(line.0)
                            .font(.fastingCaption)
                            .foregroundStyle(FastingLensTheme.slate)
                        Spacer()
                        Text(line.1)
                            .font(.fastingCaption)
                            .foregroundStyle(FastingLensTheme.ink)
                    }
                }
            }
            .padding(.leading, 10)
        }
        .padding(10)
        .background(FastingLensTheme.cloud.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var toolEmoji: String {
        switch toolResult.toolName {
        case "record_water": return "💧"
        case "record_weight": return "⚖️"
        case "mark_cheat_meal": return "🍕"
        case "adjust_plan": return "📋"
        case "get_today_summary": return "📊"
        case "get_weight_trend": return "📈"
        case "get_weekly_report": return "📰"
        case "record_meal", "recognize_food": return "🍜"
        default: return "🔧"
        }
    }

    private var toolAccent: Color {
        switch toolResult.toolName {
        case "record_water": return FastingLensTheme.mint
        case "record_weight": return FastingLensTheme.lemon
        case "record_meal", "recognize_food": return FastingLensTheme.flame
        default: return FastingLensTheme.slate
        }
    }

    private var toolTitle: String {
        switch toolResult.toolName {
        case "record_water": return "饮水记录"
        case "record_weight": return "体重记录"
        case "mark_cheat_meal": return "放纵餐标记"
        case "adjust_plan": return "计划调整"
        case "get_today_summary": return "今日摘要"
        case "get_weight_trend": return "体重趋势"
        case "get_weekly_report": return "周报"
        case "record_meal", "recognize_food": return "餐食结果"
        default: return toolResult.toolName
        }
    }

    private var parsedLines: [(String, String)] {
        parsedObject.map { key, value in
            (displayKey(key), displayValue(value))
        }
        .sorted { $0.0 < $1.0 }
        .prefix(4)
        .map { $0 }
    }

    private func displayKey(_ key: String) -> String {
        switch key {
        case "ml": return "毫升"
        case "today_total": return "今日累计"
        case "weight": return "体重"
        case "current_weight": return "当前体重"
        case "fasting_hours": return "断食时长"
        case "eating_hours": return "进食窗口"
        case "daily_calorie_goal": return "热量目标"
        case "daily_water_goal": return "饮水目标"
        case "today_calories": return "今日热量"
        case "today_water_ml": return "今日饮水"
        case "weekly_meals": return "记录餐次"
        case "weekly_calories": return "周热量"
        case "weekly_water": return "周饮水"
        case "estimated_total_calories", "total_calories": return "估算热量"
        case "items", "food_items": return "食物项"
        case "meal_type": return "餐次"
        case "points": return "点数"
        case "note", "notes": return "备注"
        case "confidence": return "置信度"
        case "requires_confirmation": return "需确认"
        case "name": return "名称"
        case "portion": return "份量"
        case "estimated_calories": return "估算卡路里"
        case "today_steps": return "今日步数"
        case "active_calories": return "活动消耗"
        case "basal_calories": return "基础代谢"
        case "estimated_tdee": return "预估TDEE"
        case "calorie_deficit": return "热量缺口"
        case "is_authorized": return "已授权"
        case "status": return "状态"
        case "message": return "消息"
        case "goal": return "目标"
        case "progress": return "进度"
        case "date": return "日期"
        case "count": return "次数"
        case "average": return "平均"
        case "total": return "合计"
        default: return key
        }
    }

    private func displayValue(_ value: Any) -> String {
        switch value {
        case let number as NSNumber:
            return number.stringValue
        case let string as String:
            return string
        default:
            return "\(value)"
        }
    }
}

private struct ChatLoadingRow: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(FastingLensTheme.mint)
                        .frame(width: 8, height: 8)
                        .offset(y: animating ? -6 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .softShadow()
            Spacer(minLength: 46)
        }
        .onAppear { animating = true }
    }
}

private struct ChatStreamingRow: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.fastingBody)
                .foregroundStyle(FastingLensTheme.charcoal)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .softShadow()
            Spacer(minLength: 46)
        }
    }
}

private struct AssistantSessionListSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var renameSessionID: UUID?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.chatSessions) { session in
                    let isActive = appState.activeChatSessionID == session.id
                    Button {
                        appState.selectChatSession(session.id)
                        isPresented = false
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(isActive ? FastingLensTheme.flame : FastingLensTheme.cloud)
                                .frame(width: 4, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.title ?? "未命名对话")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(FastingLensTheme.ink)
                                    Spacer()
                                    if isActive {
                                        Text("当前")
                                            .font(.fastingCaption)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(FastingLensTheme.flame, in: Capsule())
                                    }
                                    Text("\(session.messages.count)")
                                        .font(.fastingCaption)
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(FastingLensTheme.ink, in: Circle())
                                }
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.fastingCaption)
                                    .foregroundStyle(FastingLensTheme.slate)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            appState.deleteChatSession(session.id)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("重命名") {
                            renameSessionID = session.id
                            renameText = session.title ?? ""
                        }
                        .tint(FastingLensTheme.mint)
                    }
                }
            }
            .navigationTitle("对话历史")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { isPresented = false }
                }
            }
            .alert("重命名会话", isPresented: Binding(
                get: { renameSessionID != nil },
                set: { if !$0 { renameSessionID = nil } }
            )) {
                TextField("会话标题", text: $renameText)
                Button("取消", role: .cancel) {
                    renameSessionID = nil
                }
                Button("保存") {
                    if let renameSessionID {
                        appState.renameChatSession(renameSessionID, title: renameText)
                    }
                    renameSessionID = nil
                }
            }
        }
    }
}

private struct ToolResultCard: View {
    let result: MealRecognitionResult
    @Binding var editableMealType: String
    @Binding var editableCalories: String
    @Binding var editableNotes: String
    let onConfirm: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("🍜")
                    .font(.system(size: 24))
                Text("餐食识别结果")
                    .font(.fastingSection)
                Spacer()
                Text("置信度 \(Int(result.confidence * 100))%")
                    .font(.fastingCaption)
                    .foregroundStyle(FastingLensTheme.slate)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FastingLensTheme.cloud.opacity(0.5), in: Capsule())
            }

            TextField("餐次类型", text: $editableMealType)
                .font(.fastingBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))

            VStack(spacing: 0) {
                ForEach(Array(result.foodItems.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(item.portion)
                                .font(.fastingCaption)
                                .foregroundStyle(FastingLensTheme.slate)
                        }
                        Spacer()
                        Text("\(item.estimatedCalories) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(FastingLensTheme.flame)
                    }
                    .padding(.vertical, 8)

                    if index < result.foodItems.count - 1 {
                        Divider().foregroundStyle(FastingLensTheme.cloud)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(FastingLensTheme.cloud.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Text("总热量")
                    .font(.fastingLabel)
                    .foregroundStyle(FastingLensTheme.slate)
                TextField("kcal", text: $editableCalories)
                    .keyboardType(.numberPad)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
            }

            TextEditor(text: $editableNotes)
                .font(.fastingBody)
                .frame(height: 72)
                .padding(8)
                .background(FastingLensTheme.cloud.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("✓ 确认保存")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FastingLensTheme.mintGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                }

                Button(action: onReset) {
                    Text("清空")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(FastingLensTheme.slate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FastingLensTheme.cloud.opacity(0.5), in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
        .cardShadow()
    }
}

struct DataScreen: View {
    @Environment(AppState.self) private var appState
    @State private var range = 0
    private let heatmapColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("时间维度", selection: $range) {
                        Text("日").tag(0)
                        Text("周").tag(1)
                        Text("月").tag(2)
                    }
                    .pickerStyle(.segmented)

                    chartCard(emoji: "⚖️", title: "体重趋势") {
                        if appState.persisted.weights.isEmpty {
                            EmptyChartHint(emoji: "⚖️", text: "还没有体重记录，去助手里记一次吧")
                        } else {
                            Chart(weightSeries) { item in
                                LineMark(
                                    x: .value("日期", item.date),
                                    y: .value("体重", item.weight)
                                )
                                .foregroundStyle(FastingLensTheme.flame)
                                PointMark(
                                    x: .value("日期", item.date),
                                    y: .value("体重", item.weight)
                                )
                                .foregroundStyle(FastingLensTheme.flame)
                            }
                            .frame(height: 220)
                        }
                    }

                    chartCard(emoji: "🔥", title: "热量统计") {
                        if calorieSeries.isEmpty {
                            EmptyChartHint(emoji: "🔥", text: "还没有餐食记录，拍照识别后就有啦")
                        } else {
                            Chart(calorieSeries, id: \.date) { item in
                                BarMark(
                                    x: .value("日期", item.date),
                                    y: .value("热量", item.value)
                                )
                                .foregroundStyle(item.value > appState.persisted.settings.dailyCalorieGoal ? FastingLensTheme.coral : FastingLensTheme.flame)
                            }
                            .frame(height: 220)
                        }
                    }

                    chartCard(emoji: "📅", title: "断食打卡") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("最近 35 天")
                                .font(.fastingLabel)
                                .foregroundStyle(FastingLensTheme.slate)

                            LazyVGrid(columns: heatmapColumns, spacing: 8) {
                                ForEach(checkInDays, id: \.self) { day in
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            completionRatio(for: day) > 0
                                                ? LinearGradient(colors: [FastingLensTheme.mint, FastingLensTheme.mint.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                                : LinearGradient(colors: [FastingLensTheme.cloud.opacity(0.4), FastingLensTheme.cloud.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                                        )
                                        .frame(height: 34)
                                        .overlay {
                                            Text(day.formatted(.dateTime.day()))
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundStyle(completionRatio(for: day) > 0 ? .white : FastingLensTheme.slate.opacity(0.7))
                                        }
                                }
                            }

                            HStack(spacing: 12) {
                                Label("已打卡", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(FastingLensTheme.mint)
                                Label("未记录", systemImage: "circle")
                                    .foregroundStyle(FastingLensTheme.slate)
                            }
                            .font(.fastingLabel)
                        }
                    }

                    chartCard(emoji: "🎯", title: "今日目标") {
                        VStack(spacing: 14) {
                            goalRow(
                                icon: "flame.fill",
                                label: "热量",
                                current: appState.todayCalories,
                                goal: appState.persisted.settings.dailyCalorieGoal,
                                unit: "kcal",
                                tint: FastingLensTheme.flame
                            )
                            goalRow(
                                icon: "drop.fill",
                                label: "饮水",
                                current: appState.todayWaterML,
                                goal: appState.persisted.settings.dailyWaterGoal,
                                unit: "ml",
                                tint: FastingLensTheme.mint
                            )

                            let streakCount = currentStreak
                            HStack(spacing: 8) {
                                Image(systemName: "flame.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(FastingLensTheme.coral)
                                Text("连续打卡")
                                    .font(.fastingBody)
                                Spacer()
                                Text("\(streakCount) 天")
                                    .font(.fastingDigits)
                                    .foregroundStyle(streakCount > 0 ? FastingLensTheme.coral : FastingLensTheme.slate)
                            }
                        }
                    }

                    chartCard(emoji: "💧", title: "饮水统计") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(appState.todayWaterML)")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(FastingLensTheme.mint)
                                Text("/ \(appState.persisted.settings.dailyWaterGoal) ml")
                                    .font(.fastingLabel)
                                    .foregroundStyle(FastingLensTheme.slate)
                            }

                            ProgressView(
                                value: Double(appState.todayWaterML),
                                total: Double(max(appState.persisted.settings.dailyWaterGoal, 1))
                            )
                            .tint(FastingLensTheme.mint)

                            let pct = min(Double(appState.todayWaterML) / Double(max(appState.persisted.settings.dailyWaterGoal, 1)), 1)
                            Text("\(Int(pct * 100))% 完成")
                                .font(.fastingCaption)
                                .foregroundStyle(FastingLensTheme.slate)
                        }
                    }

                    chartCard(emoji: "🍽️", title: "历史餐食") {
                        if appState.persisted.meals.isEmpty {
                            EmptyChartHint(emoji: "🍽️", text: "还没有历史记录，快去记一餐吧")
                        } else {
                            VStack(spacing: 0) {
                                let meals = Array(appState.persisted.meals.prefix(5))
                                ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                                    NavigationLink {
                                        MealDetailView(meal: meal)
                                    } label: {
                                        mealRow(meal: meal)
                                    }
                                    .buttonStyle(.plain)

                                    if index < meals.count - 1 {
                                        Divider().foregroundStyle(FastingLensTheme.cloud.opacity(0.5))
                                    }
                                }

                                if appState.persisted.meals.count > 5 {
                                    Divider().foregroundStyle(FastingLensTheme.cloud.opacity(0.5))
                                    NavigationLink {
                                        MealListView()
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Text("查看全部 \(appState.persisted.meals.count) 条记录")
                                                .font(.fastingLabel)
                                                .foregroundStyle(FastingLensTheme.flame)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(FastingLensTheme.flame)
                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("数据")
        }
    }

    private var weightSeries: [StoredWeightRecord] {
        appState.persisted.weights.sorted { $0.date < $1.date }
    }

    private var calorieSeries: [(date: Date, value: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: appState.persisted.meals) { calendar.startOfDay(for: $0.loggedAt) }
        return grouped
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.totalCalories }) }
            .sorted { $0.0 < $1.0 }
    }

    private var checkInDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<35).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        .sorted()
    }

    private func completionRatio(for day: Date) -> Double {
        appState.completedCheckInDates.contains(Calendar.current.startOfDay(for: day)) ? 1 : 0
    }

    private func completionColor(for day: Date) -> Color {
        switch completionRatio(for: day) {
        case 1:
            return FastingLensTheme.mint
        default:
            return FastingLensTheme.cloud
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var streak = 0
        var day = today
        while appState.completedCheckInDates.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private func goalRow(icon: String, label: String, current: Int, goal: Int, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.fastingBody)
                Spacer()
                Text("\(current) / \(goal) \(unit)")
                    .font(.fastingLabel)
                    .foregroundStyle(FastingLensTheme.slate)
            }
            ProgressView(value: Double(current), total: Double(max(goal, 1)))
                .tint(tint)
        }
    }

    private func mealRow(meal: StoredMealRecord) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(mealTypeColor(meal.mealType))
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(meal.mealType)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(meal.totalCalories) kcal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(FastingLensTheme.flame)
                }
                HStack {
                    Text(meal.loggedAt.formatted(date: .abbreviated, time: .shortened))
                    if !meal.items.isEmpty {
                        Text("· \(meal.items.map(\.name).joined(separator: "、"))")
                    }
                }
                .font(.fastingCaption)
                .foregroundStyle(FastingLensTheme.slate)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }

    private func mealTypeColor(_ type: String) -> Color {
        switch type {
        case "早餐": return FastingLensTheme.lemon
        case "午餐": return FastingLensTheme.flame
        case "晚餐": return FastingLensTheme.mint
        default: return FastingLensTheme.slate
        }
    }

    private func chartCard<Content: View>(emoji: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 20))
                Text(title)
                    .font(.fastingSection)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
        .cardShadow()
    }
}

private struct EmptyChartHint: View {
    var emoji: String = "📊"
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 36))
            Text(text)
                .font(.fastingLabel)
                .foregroundStyle(FastingLensTheme.slate)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                .foregroundStyle(FastingLensTheme.cloud)
        )
    }
}

private struct MealListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(appState.persisted.meals) { meal in
                NavigationLink {
                    MealDetailView(meal: meal)
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(mealTypeColor(meal.mealType))
                            .frame(width: 4, height: 40)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(meal.mealType)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Spacer()
                                Text("\(meal.totalCalories) kcal")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(FastingLensTheme.flame)
                            }
                            HStack {
                                Text(meal.loggedAt.formatted(date: .abbreviated, time: .shortened))
                                if !meal.items.isEmpty {
                                    Text("· \(meal.items.map(\.name).joined(separator: "、"))")
                                }
                            }
                            .font(.fastingCaption)
                            .foregroundStyle(FastingLensTheme.slate)
                            .lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle("全部餐食记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mealTypeColor(_ type: String) -> Color {
        switch type {
        case "早餐": return FastingLensTheme.lemon
        case "午餐": return FastingLensTheme.flame
        case "晚餐": return FastingLensTheme.mint
        default: return FastingLensTheme.slate
        }
    }
}

private struct MealDetailView: View {
    let meal: StoredMealRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Text(mealEmoji)
                        .font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.mealType)
                            .font(.fastingSection)
                        Text(meal.loggedAt.formatted(date: .long, time: .shortened))
                            .font(.fastingCaption)
                            .foregroundStyle(FastingLensTheme.slate)
                    }
                    Spacer()
                }

                // Total calories card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("总热量")
                            .font(.fastingLabel)
                            .foregroundStyle(FastingLensTheme.slate)
                        Text("\(meal.totalCalories)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(FastingLensTheme.flame)
                        + Text(" kcal")
                            .font(.fastingLabel)
                            .foregroundStyle(FastingLensTheme.slate)
                    }
                    Spacer()
                }
                .padding(18)
                .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                .cardShadow()

                // Food items
                if !meal.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("食物明细")
                            .font(.fastingLabel)
                            .foregroundStyle(FastingLensTheme.slate)

                        VStack(spacing: 0) {
                            ForEach(Array(meal.items.enumerated()), id: \.element.id) { index, item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.fastingBody)
                                        if !item.portion.isEmpty {
                                            Text(item.portion)
                                                .font(.fastingCaption)
                                                .foregroundStyle(FastingLensTheme.slate)
                                        }
                                    }
                                    Spacer()
                                    Text("\(item.estimatedCalories) kcal")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(FastingLensTheme.flame)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)

                                if index < meal.items.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                        .cardShadow()
                    }
                }

                // Notes
                if !meal.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.fastingLabel)
                            .foregroundStyle(FastingLensTheme.slate)
                        Text(meal.notes)
                            .font(.fastingBody)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                            .cardShadow()
                    }
                }
            }
            .padding()
        }
        .background(FastingLensTheme.paper.ignoresSafeArea())
        .navigationTitle("餐食详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mealEmoji: String {
        switch meal.mealType {
        case "早餐": return "🌅"
        case "午餐": return "☀️"
        case "晚餐": return "🌙"
        case "加餐": return "🍪"
        case "放纵餐": return "🍕"
        default: return "🍽️"
        }
    }
}

struct ProfileScreen: View {
    @Environment(AppState.self) private var appState
    @State private var activeSheet: ProfileSheetType?
    @State private var selectedPhoto: PhotosPickerItem?

    private enum ProfileSheetType: Identifiable {
        case personal, goals, fasting, aiConfig, health, data
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Avatar card
                    let settings = appState.persisted.settings
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = settings.avatarImageData,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [FastingLensTheme.flame.opacity(0.2), FastingLensTheme.lemon.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 72, height: 72)
                                        .overlay {
                                            Text(String(settings.displayName.prefix(1)).uppercased())
                                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                                .foregroundStyle(FastingLensTheme.flame)
                                        }
                                }
                                Circle()
                                    .fill(FastingLensTheme.snow)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(FastingLensTheme.slate)
                                    }
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(settings.displayName)
                                .font(.fastingSection)
                            Text("已加入 \(appState.joinedDays) 天")
                                .font(.fastingCaption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(FastingLensTheme.flame.opacity(0.12), in: Capsule())
                                .foregroundStyle(FastingLensTheme.flame)

                            HStack(spacing: 16) {
                                Text("\(settings.startWeight.formatted(.number.precision(.fractionLength(1)))) → \(settings.targetWeight.formatted(.number.precision(.fractionLength(1)))) kg")
                                    .font(.fastingCaption)
                                    .foregroundStyle(FastingLensTheme.slate)
                                Text("已减 \(max(settings.startWeight - appState.currentWeight, 0).formatted(.number.precision(.fractionLength(1)))) kg")
                                    .font(.fastingCaption)
                                    .foregroundStyle(FastingLensTheme.mint)
                            }
                        }
                        Spacer()
                    }
                    .padding(18)
                    .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                    .cardShadow()

                    // Settings menu
                    VStack(spacing: 0) {
                        profileMenuRow(emoji: "👤", title: "个人信息", subtitle: settings.displayName) {
                            activeSheet = .personal
                        }
                        Divider().padding(.leading, 48)
                        profileMenuRow(emoji: "🎯", title: "目标管理", subtitle: "\(settings.dailyCalorieGoal) kcal · \(settings.dailyWaterGoal) ml") {
                            activeSheet = .goals
                        }
                        Divider().padding(.leading, 48)
                        profileMenuRow(emoji: "⏱️", title: "断食计划", subtitle: "\(appState.persisted.plan.fastingHours):\(appState.persisted.plan.eatingHours)") {
                            activeSheet = .fasting
                        }
                        Divider().padding(.leading, 48)
                        profileMenuRow(emoji: "🤖", title: "AI 配置", subtitle: "") {
                            activeSheet = .aiConfig
                        }
                        Divider().padding(.leading, 48)
                        profileMenuRow(emoji: "❤️", title: "健康数据", subtitle: appState.healthKit.isAuthorized ? "已授权" : "未授权") {
                            activeSheet = .health
                        }
                        Divider().padding(.leading, 48)
                        profileMenuRow(emoji: "💾", title: "数据管理", subtitle: "") {
                            activeSheet = .data
                        }
                    }
                    .padding(.vertical, 4)
                    .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                    .cardShadow()
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("我的")
            .sheet(item: $activeSheet) { type in
                switch type {
                case .personal:
                    ProfilePersonalSheet()
                case .goals:
                    ProfileGoalsSheet()
                case .fasting:
                    ProfileFastingSheet()
                case .aiConfig:
                    NavigationStack { AIConfigScreen() }
                case .health:
                    ProfileHealthSheet()
                case .data:
                    ProfileDataSheet()
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let jpeg = uiImage.jpegData(compressionQuality: 0.8) {
                        appState.updateAvatar(jpeg)
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    private func profileMenuRow(emoji: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 22))
                    .frame(width: 32)
                Text(title)
                    .font(.fastingBody)
                    .foregroundStyle(FastingLensTheme.ink)
                Spacer()
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.fastingCaption)
                        .foregroundStyle(FastingLensTheme.slate)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FastingLensTheme.cloud)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Sheets

private struct ProfilePersonalSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var assistantName = ""
    @State private var startWeight = 65.0
    @State private var targetWeight = 60.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sheetField(label: "首页称呼", text: $displayName)
                    sheetField(label: "助手名字", text: $assistantName)
                    Divider().foregroundStyle(FastingLensTheme.cloud)
                    Stepper("起始体重：\(startWeight.formatted(.number.precision(.fractionLength(1)))) kg", value: $startWeight, in: 35...150, step: 0.5)
                        .font(.fastingBody)
                    Stepper("目标体重：\(targetWeight.formatted(.number.precision(.fractionLength(1)))) kg", value: $targetWeight, in: 35...150, step: 0.5)
                        .font(.fastingBody)
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("个人信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let s = appState.persisted.settings
                        appState.updateUserSettings(
                            displayName: displayName, assistantName: assistantName,
                            startWeight: startWeight, targetWeight: targetWeight,
                            dailyCalorieGoal: s.dailyCalorieGoal, dailyWaterGoal: s.dailyWaterGoal,
                            defaultMealType: s.defaultMealType, saveOriginalPhotos: s.saveOriginalPhotos
                        )
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            let s = appState.persisted.settings
            displayName = s.displayName
            assistantName = s.assistantName
            startWeight = s.startWeight
            targetWeight = s.targetWeight
        }
        .presentationDetents([.medium, .large])
    }

    private func sheetField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.fastingCaption)
                .foregroundStyle(FastingLensTheme.slate)
            TextField(label, text: text)
                .font(.fastingBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
        }
    }
}

private struct ProfileGoalsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var dailyCalorieGoal = 1600
    @State private var dailyWaterGoal = 2000
    @State private var defaultMealType = "正餐"
    @State private var saveOriginalPhotos = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Stepper("每日热量：\(dailyCalorieGoal) kcal", value: $dailyCalorieGoal, in: 800...4000, step: 50)
                        .font(.fastingBody)
                    Stepper("每日饮水：\(dailyWaterGoal) ml", value: $dailyWaterGoal, in: 500...5000, step: 100)
                        .font(.fastingBody)
                    Divider().foregroundStyle(FastingLensTheme.cloud)
                    HStack {
                        Text("默认餐次")
                            .font(.fastingBody)
                        Spacer()
                        Picker("默认餐次", selection: $defaultMealType) {
                            Text("早餐").tag("早餐")
                            Text("午餐").tag("午餐")
                            Text("晚餐").tag("晚餐")
                            Text("加餐").tag("加餐")
                            Text("正餐").tag("正餐")
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("保存原图", isOn: $saveOriginalPhotos)
                        .font(.fastingBody)
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("目标管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let s = appState.persisted.settings
                        appState.updateUserSettings(
                            displayName: s.displayName, assistantName: s.assistantName,
                            startWeight: s.startWeight, targetWeight: s.targetWeight,
                            dailyCalorieGoal: dailyCalorieGoal, dailyWaterGoal: dailyWaterGoal,
                            defaultMealType: defaultMealType, saveOriginalPhotos: saveOriginalPhotos
                        )
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            let s = appState.persisted.settings
            dailyCalorieGoal = s.dailyCalorieGoal
            dailyWaterGoal = s.dailyWaterGoal
            defaultMealType = s.defaultMealType
            saveOriginalPhotos = s.saveOriginalPhotos
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ProfileFastingSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var fastingHours = 16.0
    @State private var eatingHours = 8.0
    @State private var cycleStartedAt = Date.now
    @State private var remindersEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Stepper("断食时长：\(Int(fastingHours)) 小时", value: $fastingHours, in: 12...20, step: 1)
                        .font(.fastingBody)
                    Stepper("进食窗口：\(Int(eatingHours)) 小时", value: $eatingHours, in: 4...12, step: 1)
                        .font(.fastingBody)
                    Divider().foregroundStyle(FastingLensTheme.cloud)
                    DatePicker("周期起点", selection: $cycleStartedAt)
                        .font(.fastingBody)
                    Toggle("通知提醒", isOn: $remindersEnabled)
                        .font(.fastingBody)
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("断食计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        appState.updatePlan(
                            fastingHours: Int(fastingHours),
                            eatingHours: Int(eatingHours),
                            cycleStartedAt: cycleStartedAt,
                            remindersEnabled: remindersEnabled
                        )
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            let p = appState.persisted.plan
            fastingHours = Double(p.fastingHours)
            eatingHours = Double(p.eatingHours)
            cycleStartedAt = p.cycleStartedAt
            remindersEnabled = p.remindersEnabled
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ProfileHealthSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if appState.healthKit.isAvailable {
                        HStack {
                            Text("HealthKit 授权")
                                .font(.fastingBody)
                            Spacer()
                            if appState.healthKit.isAuthorized {
                                Label("已授权", systemImage: "checkmark.circle.fill")
                                    .font(.fastingLabel)
                                    .foregroundStyle(FastingLensTheme.mint)
                            } else {
                                Button("请求授权") {
                                    Task {
                                        await appState.healthKit.requestAuthorization()
                                        await appState.healthKit.refreshTodayData()
                                    }
                                }
                                .font(.fastingLabel)
                                .foregroundStyle(FastingLensTheme.flame)
                            }
                        }

                        if appState.healthKit.isAuthorized {
                            Divider().foregroundStyle(FastingLensTheme.cloud)
                            healthRow(title: "今日步数", value: "\(appState.healthKit.todaySteps)", color: FastingLensTheme.flame)
                            healthRow(title: "活动消耗", value: "\(appState.healthKit.todayActiveCalories) kcal", color: FastingLensTheme.flame)
                            healthRow(title: "基础代谢", value: "\(appState.healthKit.todayBasalCalories) kcal", color: FastingLensTheme.slate)
                            Divider().foregroundStyle(FastingLensTheme.cloud)
                            healthRow(title: "预估 TDEE", value: "\(appState.healthKit.estimatedTDEE) kcal", color: FastingLensTheme.lime)
                            let deficit = appState.healthKit.calorieDeficit(intake: appState.todayCalories)
                            healthRow(title: "热量缺口", value: "\(deficit) kcal", color: deficit > 0 ? FastingLensTheme.mint : FastingLensTheme.coral)
                        }
                    } else {
                        Text("当前设备不支持 HealthKit")
                            .font(.fastingBody)
                            .foregroundStyle(FastingLensTheme.slate)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    }
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("健康数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func healthRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.fastingBody)
            Spacer()
            Text(value)
                .font(.fastingDigits)
                .foregroundStyle(color)
        }
    }
}

private struct ProfileDataSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var showClearConfirmation = false
    @State private var dataMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Button {
                        do {
                            exportURL = try appState.exportStateURL()
                            dataMessage = "导出文件已生成，可以直接分享。"
                        } catch {
                            dataMessage = "导出失败：\(error.localizedDescription)"
                        }
                    } label: {
                        Text("📦 生成导出文件")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FastingLensTheme.mintGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("分享导出 JSON", systemImage: "square.and.arrow.up")
                                .font(.fastingBody)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Button {
                        showClearConfirmation = true
                    } label: {
                        Text("清空所有数据")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FastingLensTheme.coral, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                    }

                    if !dataMessage.isEmpty {
                        Text(dataMessage)
                            .font(.fastingCaption)
                            .foregroundStyle(FastingLensTheme.slate)
                    }
                }
                .padding()
            }
            .background(FastingLensTheme.paper.ignoresSafeArea())
            .navigationTitle("数据管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog("确认清空所有数据？", isPresented: $showClearConfirmation) {
                Button("清空", role: .destructive) {
                    appState.clearAllData()
                    exportURL = nil
                    dataMessage = "所有本地数据已清空。"
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct AIConfigScreen: View {
    private let lockedSystemPrompt = "你是一个专业的中文食物营养分析师。你必须精确识别图片中的每一种食物，估算其份量（克/毫升/个）和对应热量（kcal）。热量按中国食物成分表计算。只返回严格 JSON，禁止 Markdown。"
    private let lockedUserTemplate = "请仔细分析这张图片中的所有食物。对每种食物分别给出：名称、份量估算（根据容器和餐具比例判断大小，写明克数或个数）、该份量对应的热量。份量要具体（如「约200g」「2个」「一碗约300ml」），热量要根据份量精确计算。返回严格 JSON 格式。"
    private let hiddenPlaceholder = "（已隐藏，不可修改）"

    @Environment(AppState.self) private var appState
    @State private var mode = 0
    @State private var draft = ""
    @State private var validationMessage = "还没有校验当前配置。"
    @State private var preset = "Claude"
    @State private var configName = ""
    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var rootPath = ""
    @State private var useBearerAuthorization = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Text("🤖")
                        .font(.system(size: 28))
                    Text("AI 模型配置")
                        .font(.fastingHero)
                }

                Picker("模式", selection: $mode) {
                    Text("📝 表单").tag(0)
                    Text("{ } JSON").tag(1)
                }
                .pickerStyle(.segmented)
                .tint(FastingLensTheme.flame)

                Text("表单模式和 JSON 模式共用同一份配置")
                    .font(.fastingCaption)
                    .foregroundStyle(FastingLensTheme.slate)

                if mode == 0 {
                    formEditor
                } else {
                    TextEditor(text: $draft)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(minHeight: 320)
                        .padding(12)
                        .background(FastingLensTheme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous)
                                .strokeBorder(FastingLensTheme.cloud, lineWidth: 1)
                        )
                }

                VStack(spacing: 10) {
                    Button {
                        if mode == 0 { syncDraftFromForm() }
                        do {
                            let provider = try AISettingsDraft(rawJSON: draft).validate()
                            validationMessage = "✅ 校验通过：\(provider.name)"
                        } catch {
                            validationMessage = "❌ 校验失败：\(error.localizedDescription)"
                        }
                    } label: {
                        Text("🔍 校验配置")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(FastingLensTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(FastingLensTheme.lemonGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                    }

                    Button {
                        if mode == 0 { syncDraftFromForm() }
                        saveLockedConfig()
                    } label: {
                        Text("💾 保存配置")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(FastingLensTheme.flameGradient, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
                    }
                }

                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.fastingLabel)
                        .foregroundStyle(FastingLensTheme.slate)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FastingLensTheme.cloud.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
        }
        .background(FastingLensTheme.paper.ignoresSafeArea())
        .navigationTitle("AI 配置")
        .onAppear {
            draft = redactPromptFields(in: appState.persisted.providerJSONString)
            loadFormFromDraft()
        }
        .onChange(of: mode) { _, newValue in
            if newValue == 1 {
                syncDraftFromForm()
                draft = redactPromptFields(in: draft)
            } else {
                loadFormFromDraft()
            }
        }
    }

    private var formEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                presetCard(emoji: "🟣", name: "Claude", tag: "Claude")
                presetCard(emoji: "🟢", name: "OpenAI", tag: "OpenAI")
                presetCard(emoji: "⚙️", name: "自定义", tag: "自定义")
            }
            .onChange(of: preset) { _, _ in
                applyPresetDefaults()
            }

            VStack(spacing: 12) {
                aiConfigField(icon: "tag", label: "配置名称", text: $configName)
                aiConfigField(icon: "link", label: "接口地址", text: $endpoint, keyboard: .URL)
                aiConfigField(icon: "key", label: "API Key", text: $apiKey)
                aiConfigField(icon: "cpu", label: "模型名称", text: $model)
                aiConfigField(icon: "arrow.turn.down.right", label: "响应路径", text: $rootPath)

                HStack {
                    Image(systemName: "shield")
                        .font(.system(size: 14))
                        .foregroundStyle(FastingLensTheme.slate)
                        .frame(width: 28)
                    Toggle("使用 Bearer 鉴权", isOn: $useBearerAuthorization)
                        .font(.fastingBody)
                }
            }
            .padding(16)
            .background(FastingLensTheme.snow, in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerM, style: .continuous))
            .cardShadow()

            Text("Claude：`/v1/messages` + `content.0.text`\nOpenAI：`/v1/chat/completions` + `choices.0.message.content`")
                .font(.fastingCaption)
                .foregroundStyle(FastingLensTheme.slate)
        }
    }

    private func presetCard(emoji: String, name: String, tag: String) -> some View {
        Button {
            preset = tag
        } label: {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 24))
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(preset == tag ? FastingLensTheme.flame : FastingLensTheme.slate)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous)
                    .fill(preset == tag ? FastingLensTheme.flame.opacity(0.08) : FastingLensTheme.cloud.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous)
                    .strokeBorder(preset == tag ? FastingLensTheme.flame : .clear, lineWidth: 2)
            )
            .scaleEffect(preset == tag ? 1.02 : 1)
            .animation(.spring(response: 0.3), value: preset)
        }
        .buttonStyle(.plain)
    }

    private func aiConfigField(icon: String, label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(FastingLensTheme.slate)
                .frame(width: 28)
            TextField(label, text: text)
                .font(.fastingBody)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FastingLensTheme.cloud.opacity(0.4), in: RoundedRectangle(cornerRadius: FastingLensTheme.cornerS, style: .continuous))
        }
    }

    private func loadFormFromDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let provider = try? AISettingsDraft(rawJSON: draft).validate() else {
            applyPresetDefaults()
            return
        }

        configName = provider.name
        endpoint = provider.endpoint.absoluteString
        model = provider.request.model
        rootPath = provider.response.rootPath
        if provider.headers.keys.contains(where: { $0.caseInsensitiveCompare("anthropic-version") == .orderedSame }) ||
            provider.endpoint.path.contains("/messages") {
            preset = "Claude"
            apiKey = provider.headers["x-api-key"] ?? provider.headers["X-API-Key"] ?? ""
            useBearerAuthorization = false
        } else {
            preset = provider.endpoint.path.contains("/chat/completions") ? "OpenAI" : "自定义"
            let auth = provider.headers["Authorization"] ?? provider.headers["authorization"] ?? ""
            apiKey = auth.replacingOccurrences(of: "Bearer ", with: "")
            useBearerAuthorization = true
        }
    }

    private func applyPresetDefaults() {
        if configName.isEmpty {
            configName = preset == "Claude" ? "我的 Claude 配置" : "我的 AI 配置"
        }

        switch preset {
        case "Claude":
            if endpoint.isEmpty || endpoint.contains("/chat/completions") {
                endpoint = "https://api.78code.cc/v1/messages"
            }
            if model.isEmpty {
                model = "opus"
            }
            rootPath = "content.0.text"
            useBearerAuthorization = false
        case "OpenAI":
            if endpoint.isEmpty || endpoint.contains("/messages") {
                endpoint = "https://api.openai.com/v1/chat/completions"
            }
            if model.isEmpty {
                model = "gpt-4o"
            }
            rootPath = "choices.0.message.content"
            useBearerAuthorization = true
        default:
            if rootPath.isEmpty {
                rootPath = "choices.0.message.content"
            }
        }
    }

    private func syncDraftFromForm() {
        guard let endpointURL = URL(string: endpoint.isEmpty ? "https://example.com/v1/chat/completions" : endpoint) else { return }

        let headers: [String: String]
        if preset == "Claude" && !useBearerAuthorization {
            headers = [
                "x-api-key": apiKey.isEmpty ? "REPLACE_ME" : apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            ]
        } else {
            let authValue = useBearerAuthorization ? "Bearer \(apiKey.isEmpty ? "REPLACE_ME" : apiKey)" : (apiKey.isEmpty ? "REPLACE_ME" : apiKey)
            headers = [
                "Authorization": authValue,
                "content-type": "application/json"
            ]
        }

        let provider = ProviderConfig(
            name: configName.isEmpty ? "我的 AI 配置" : configName,
            isEnabled: true,
            endpoint: endpointURL,
            method: .post,
            headers: headers,
            request: .init(
                model: model.isEmpty ? "unset-model" : model,
                temperature: 0.2,
                systemPrompt: lockedSystemPrompt,
                userTemplate: lockedUserTemplate,
                imageFieldMode: .base64,
                bodyTemplate: defaultBodyTemplate(for: preset)
            ),
            response: .init(
                format: .json,
                rootPath: rootPath.isEmpty ? "choices.0.message.content" : rootPath,
                schemaVersion: "meal-v1"
            ),
            behavior: .init(
                timeoutSeconds: 45,
                requiresManualConfirmation: true,
                minConfidenceToAutofill: 0.8,
                saveRequestLog: true,
                saveResponseLog: true
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(provider),
           let json = String(data: data, encoding: .utf8) {
            draft = json
        }
    }

    private func saveLockedConfig() {
        do {
            let parsed = try AISettingsDraft(rawJSON: draft).validate()
            var locked = parsed
            locked.request.systemPrompt = lockedSystemPrompt
            locked.request.userTemplate = lockedUserTemplate

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(locked)
            guard let json = String(data: data, encoding: .utf8) else {
                validationMessage = "保存失败：配置编码异常。"
                return
            }

            draft = redactPromptFields(in: json)
            appState.updateProviderJSONString(json)
            appState.updateAssistantSystemPromptTemplate(defaultAssistantSystemPromptTemplate)
            validationMessage = "已保存到本地（提示词已锁定）。"
        } catch {
            validationMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func redactPromptFields(in rawJSON: String) -> String {
        guard let data = rawJSON.data(using: .utf8),
              var provider = try? JSONDecoder().decode(ProviderConfig.self, from: data) else {
            return rawJSON
        }

        provider.request.systemPrompt = hiddenPlaceholder
        provider.request.userTemplate = hiddenPlaceholder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let redacted = try? encoder.encode(provider),
              let string = String(data: redacted, encoding: .utf8) else {
            return rawJSON
        }
        return string
    }

    private func defaultBodyTemplate(for preset: String) -> String {
        if preset == "Claude" {
            return "{\n  \"model\": {{model}},\n  \"max_tokens\": 1024,\n  \"temperature\": {{temperature}},\n  \"system\": {{systemPrompt}},\n  \"messages\": [\n    {\n      \"role\": \"user\",\n      \"content\": [\n        {\n          \"type\": \"text\",\n          \"text\": {{userPrompt}}\n        },\n        {\n          \"type\": \"image\",\n          \"source\": {\n            \"type\": \"base64\",\n            \"media_type\": \"image/jpeg\",\n            \"data\": {{imageBase64}}\n          }\n        }\n      ]\n    }\n  ]\n}"
        }

        return "{\n  \"model\": {{model}},\n  \"temperature\": {{temperature}},\n  \"messages\": [\n    {\n      \"role\": \"system\",\n      \"content\": {{systemPrompt}}\n    },\n    {\n      \"role\": \"user\",\n      \"content\": [\n        {\n          \"type\": \"text\",\n          \"text\": {{userPrompt}}\n        },\n        {\n          \"type\": \"image_url\",\n          \"image_url\": {\n            \"url\": {{imageDataURL}}\n          }\n        }\n      ]\n    }\n  ],\n  \"response_format\": {\n    \"type\": \"json_object\"\n  }\n}"
    }
}
