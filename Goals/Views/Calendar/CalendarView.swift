//
//  CalendarView.swift
//  GoalsV2
//
//  Created by Adolfo Gerard Montilla Gonzalez on 20-10-25.
//

import SwiftUI
import SwiftData

// =========================================================
// GUÍA RÁPIDA DE EJECUCIÓN (MENTAL MODEL)
// =========================================================
// 1) La vista se crea desde un NavigationLink/stack o desde el Preview.
// 2) SwiftUI llama a init(topic:) para inicializar el View.
// 3) Se configura el @Query filtrando las StudySession del topic.
// 4) SwiftUI evalúa body por primera vez para construir el árbol de vistas.
// 5) body usa `header`, `WeekdayRow` y `MonthGrid`.
// 6) MonthGrid llama a makeDays() para generar los "slots" del mes.
// 7) ForEach crea 35/42 celdas (dependiendo del mes) y pinta DayCell.
// 8) Cada DayCell decide su estado visual usando:
//    - shouldShowIndicator(date) -> define si muestra indicador
//    - isCompleted(date) -> calcula si se cumplió el objetivo ese día
// 9) Cuando cambia `monthOffset` (botones < y >), SwiftUI:
//    - actualiza el State
//    - vuelve a ejecutar body
//    - recalcula startOfMonth, monthTitle, makeDays() y las DayCell.
// 10) Cuando cambia el contenido de SwiftData (topicSessions),
//     @Query actualiza la lista y SwiftUI re-renderiza automáticamente.
//
// NOTA SOBRE CICLO DE VIDA EN SWIFTUI:
// - No hay "viewDidLoad". El equivalente práctico es:
//   init + primera evaluación de `body`.
// - `body` se puede ejecutar MUCHAS veces; es normal.
// - La lógica debe ser barata o estar calculada con cuidado.

struct CalendarView: View {
    // 1) Entradas inmutables de la vista
    let topic: Topic
    private let topicID: Topic.ID

    // 2) Fuente de datos reactiva desde SwiftData
    //    - Se rellena automáticamente según el filtro que definimos en init.
    @Query private var topicSessions: [StudySession]

    // 3) Estados locales de UI
    //    - completionCache NO se usa en este código, pero queda como idea de optimización.
    @State private var completionCache: [Date: Bool] = [:]
    @State private var monthOffset: Int = 0   // 0 = mes actual, -1 = anterior, etc.

    // =========================================================
    // INIT
    // =========================================================
    // 1) Este init se ejecuta al crear CalendarView(topic:).
    // 2) Guardamos topic y topicID.
    // 3) Configuramos el @Query con un Predicate capturando el topicID.
    // 4) Resultado: topicSessions tendrá SOLO sesiones del topic actual.
    init(topic: Topic)
    {
        self.topic = topic
        self.topicID = topic.id

        let topicID = topic.id
        self._topicSessions = Query(filter: #Predicate<StudySession> { session in
            session.topic.id == topicID
        })
    }

    // =========================================================
    // DEPENDENCIAS "ESTÁTICAS" DE ESTA VISTA
    // =========================================================
    // - Se calculan una vez por instancia del View.
    // - `calendar` respeta configuración del sistema.
    private let calendar: Calendar =
    {
        var cal = Calendar.current
        cal.firstWeekday = Calendar.current.firstWeekday
        return cal
    }()

    // - "Hoy" se toma al crear la vista.
    //   (Si quieres que cambie con el tiempo en vivo, habría que usar un Timer/TimelineView).
    private let today = Date()

    // =========================================================
    // LÓGICA DE NEGOCIO / UI
    // =========================================================

    // 1) Busca el primer día con sesiones para este topic.
    // 2) Se usa para NO mostrar indicadores antes de que el hábito exista.
    private func earliestTopicDay() -> Date?
    {
        topicSessions.map(\.normalizedDay).min()
    }

    // 1) Decide si debemos mostrar el indicador en una fecha.
    // 2) Reglas:
    //    - Si no hay sesiones -> no mostrar nada.
    //    - Si la fecha es anterior al primer día del topic -> no mostrar.
    //    - Si es un día pasado -> mostrar (éxito o fallo).
    //    - Si es hoy -> mostrar SOLO si se cumplió la meta.
    //    - Si es futuro -> no mostrar.
    private func shouldShowIndicator(on date: Date) -> Bool
    {
        if topicSessions.isEmpty { return false }

        let startOfDate = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: today)

        if let rawFirstDay = earliestTopicDay() {
            let firstDay = calendar.startOfDay(for: rawFirstDay)
            if startOfDate < firstDay { return false }
        }

        if startOfDate < startOfToday { return true }
        if calendar.isDate(startOfDate, inSameDayAs: startOfToday) { return isCompleted(on: date) }
        return false
    }

    // 1) Filtra todas las sesiones que caen en "date".
    // 2) Llama a DailyStatus.compute(...) para obtener estado diario.
    // 3) Devuelve true si el objetivo estuvo "met".
    private func isCompleted(on date: Date) -> Bool
    {
        let dayKey = calendar.startOfDay(for: date)

        let sessionsForDay = topicSessions.filter { session in
            calendar.isDate(session.normalizedDay, inSameDayAs: dayKey)
        }

        guard let status = DailyStatus.compute(from: sessionsForDay) else {
            return false
        }

        return status.isMet.contains(true)
    }

    // "Hoy" normalizado a inicio de día.
    private var todayStart: Date {
        calendar.startOfDay(for: today)
    }

    // 1) Calcula el primer día del mes actual.
    // 2) Luego aplica monthOffset para moverse entre meses.
    // 3) Esta propiedad se recalcula cada vez que `monthOffset` cambie.
    private var startOfMonth: Date
    {
        let components = calendar.dateComponents([.year, .month], from: todayStart)
        let baseMonthStart = calendar.date(from: components) ?? todayStart
        return calendar.date(byAdding: .month, value: monthOffset, to: baseMonthStart) ?? baseMonthStart
    }

    // 1) Formatea el título del mes en texto visible.
    private var monthTitle: String
    {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: startOfMonth)
    }

    // 1) Solo permite ir "hacia adelante" si estamos en meses pasados.
    //    - monthOffset = 0 (mes actual) -> no se puede avanzar.
    //    - monthOffset < 0 -> sí se puede volver hacia el mes actual.
    private var canGoNextMonth: Bool
    {
        monthOffset < 0
    }

    // 1) En este diseño siempre puedes ir a meses anteriores.
    private var canGoPreviousMonth: Bool
    {
        true
    }

    // 1) Botón "<": resta 1 al offset.
    // 2) Esto dispara un re-render de body.
    private func goToPreviousMonth()
    {
        monthOffset -= 1
    }

    // 1) Botón ">": suma 1 al offset si está permitido.
    private func goToNextMonth()
    {
        guard canGoNextMonth else { return }
        monthOffset += 1
    }

    // =========================================================
    // BODY (SE REEVALÚA MUCHAS VECES)
    // =========================================================
    // 1) SwiftUI ejecuta body para construir el árbol visual.
    // 2) Si cambia topicSessions o monthOffset, body se ejecuta de nuevo.
    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 20)
            {
                // 1) Header con navegación de meses + título.
                header

                VStack(spacing: 12)
                {
                    // 2) Fila de nombres de días (Lu/Ma/...)
                    WeekdayRow(calendar: calendar)

                    // 3) Parrilla del mes
                    //    - Recibe closures para decidir completado e indicador.
                    MonthGrid(
                        month: startOfMonth,
                        calendar: calendar,
                        today: today,
                        isCompleted: isCompleted(on:),
                        shouldShowIndicator: shouldShowIndicator(on:)
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Spacer(minLength: 16)
            }
            .padding(.top, 16)
        }
        // 4) Configuración del NavigationBar
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// =========================================================
// EXTENSIÓN PRIVADA: HEADER
// =========================================================
private extension CalendarView
{
    var header: some View
    {
        // 1) Colores de marca
        let brandLight = Color(red: 63/255, green: 167/255, blue: 214/255) // #3FA7D6
        let brandDark  = Color(red: 29/255, green: 53/255,  blue: 87/255)  // #1D3557

        // 2) ZStack para fondo degradado + contenido del header
        return ZStack
        {
            LinearGradient(
                colors: [brandDark, brandLight],
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(0.18)
            .ignoresSafeArea(edges: .horizontal)

            // 3) Controles del mes
            HStack(alignment: .center, spacing: 16)
            {
                // 3.1) Botón mes anterior
                Button
                {
                    goToPreviousMonth()
                }
                label:
                {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                        )
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(!canGoPreviousMonth)
                .opacity(canGoPreviousMonth ? 1 : 0.35)

                Spacer(minLength: 8)

                // 3.2) Título y subtítulo
                VStack(spacing: 4)
                {
                    Text(monthTitle)
                        .font(.headline.weight(.semibold))

                    Text("See your study streak for this topic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                Spacer(minLength: 8)

                // 3.3) Botón mes siguiente (solo si monthOffset < 0)
                Button
                {
                    goToNextMonth()
                }
                label:
                {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                        )
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(!canGoNextMonth)
                .opacity(canGoNextMonth ? 1 : 0.35)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
}

// =========================================================
// SUBVISTA: FILA DE DÍAS DE LA SEMANA
// =========================================================
private struct WeekdayRow: View
{
    let calendar: Calendar

    var body: some View
    {
        // 1) Obtiene símbolos cortos locales (Mon, Tue, ...).
        let symbols = calendar.shortStandaloneWeekdaySymbols

        // 2) Reordena según el primer día de semana del sistema.
        let ordered = Array(symbols[calendar.firstWeekday-1..<symbols.count]) + Array(symbols[0..<calendar.firstWeekday-1])

        // 3) Crea 7 columnas flexibles.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7))
        {
            // 4) Itera 7 veces (una por día)
            ForEach(ordered, id: \.self)
            { s in
                Text(s.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

// =========================================================
// SUBVISTA: PARRILLA DEL MES
// =========================================================
private struct MonthGrid: View
{
    let month: Date
    let calendar: Calendar
    let today: Date
    let isCompleted: (Date) -> Bool
    let shouldShowIndicator: (Date) -> Bool

    var body: some View
    {
        // 1) Construye la lista de DaySlot del mes.
        //    - Esto incluye "celdas vacías" al inicio/fin para alinear la semana.
        let days = makeDays()

        // 2) 7 columnas para el calendario.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 24), spacing: 0), count: 7), spacing: 10)
        {
            // 3) Itera N veces:
            //    - N suele ser 35 o 42 dependiendo del mes/alineación.
            ForEach(days, id: \.self)
            { day in
                if let dayDate = day.date
                {
                    // 4) Crea una celda real del día.
                    DayCell(
                        date: dayDate,
                        isToday: calendar.isDate(dayDate, inSameDayAs: today),
                        inCurrentMonth: day.inCurrentMonth,
                        completed: isCompleted(dayDate),
                        showIndicator: shouldShowIndicator(dayDate)
                    )
                    .frame(height: 44)
                }
                else
                {
                    // 5) Celda vacía para padding/alineación.
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    // =========================================================
    // 1) Genera DaySlot:
    //    - Calcula cuántos blanks van antes del día 1.
    //    - Agrega días reales del mes.
    //    - Rellena al final hasta completar múltiplos de 7.
    private func makeDays() -> [DaySlot]
    {
        let range = calendar.range(of: .day, in: .month, for: month) ?? (1..<31)
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let firstWeekdayIndex = calendar.component(.weekday, from: firstOfMonth)

        let leadingEmpty = (firstWeekdayIndex - calendar.firstWeekday + 7) % 7

        var result: [DaySlot] = []
        result.append(contentsOf: Array(repeating: DaySlot(date: nil, inCurrentMonth: false), count: leadingEmpty))

        // 2) Agrega cada día del 1 al último día del mes.
        for day in range
        {
            if let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth)
            {
                result.append(DaySlot(date: date, inCurrentMonth: true))
            }
        }

        // 3) Rellena al final para cerrar filas completas.
        while result.count % 7 != 0
        {
            result.append(DaySlot(date: nil, inCurrentMonth: false))
        }
        return result
    }

    struct DaySlot: Hashable
    {
        let date: Date?
        let inCurrentMonth: Bool
    }
}

// =========================================================
// SUBVISTA: CELDA DE DÍA
// =========================================================
private struct DayCell: View
{
    let date: Date
    let isToday: Bool
    let inCurrentMonth: Bool
    let completed: Bool
    let showIndicator: Bool

    // 1) Colores de marca usados para estado "success".
    private var brandLight: Color {
        Color(red: 63/255, green: 167/255, blue: 214/255) // #3FA7D6
    }

    private var brandDark: Color {
        Color(red: 29/255, green: 53/255, blue: 87/255)   // #1D3557
    }

    private var successGradient: LinearGradient
    {
        LinearGradient(
            colors: [brandLight, brandDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // 2) Estados visuales posibles por día.
    private enum VisualStatus
    {
        case none      // sin indicador (futuro, antes del inicio, etc.)
        case success   // meta cumplida
        case missed    // meta no cumplida
    }

    // 3) Traduce datos (completed/showIndicator) a un estado visual.
    private var status: VisualStatus
    {
        guard showIndicator else { return .none }
        return completed ? .success : .missed
    }

    var body: some View
    {
        // 4) Calcula colores/icono según status.
        let config = colorsAndIcon(for: status)

        // 5) Dibuja la celda en capas.
        return ZStack
        {
            // 5.1) Círculo base
            Circle()
                .fill(config.bg)
                .overlay(
                    Circle()
                        .strokeBorder(config.border, lineWidth: 1.4)
                )
                .frame(width: 32, height: 32)
                .overlay(
                    // 5.2) Anillo extra para "hoy" sin estado
                    Group
                    {
                        if isToday && status == .none
                        {
                            Circle()
                                .strokeBorder(brandLight.opacity(0.9), lineWidth: 1.6)
                        }
                    }
                )

            // 5.3) Número del día
            Text(dayNumber)
                .font(.subheadline.weight(isToday ? .semibold : .regular))
                .foregroundStyle(config.text)

            // 5.4) Icono de check/x en esquina
            if let iconName = config.iconName
            {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: iconName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(config.iconColor)
                            .padding(2)
                    }
                }
            }
        }
        .frame(height: 40)
        .opacity(inCurrentMonth ? 1 : 0.4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // 6) Obtiene el número de día como String.
    private var dayNumber: String
    {
        let comps = Calendar.current.dateComponents([.day], from: date)
        return String(comps.day ?? 0)
    }

    // 7) Define estilos por estado:
    //    - success: degradado + check blanco
    //    - missed: borde rojo + x
    //    - none: estilo neutro (o tenue fuera del mes)
    private func colorsAndIcon(for status: VisualStatus)
        -> (bg: AnyShapeStyle, border: Color, text: Color, iconName: String?, iconColor: Color)
    {
        switch status
        {
        case .success:
            return (
                bg: AnyShapeStyle(successGradient),
                border: .clear,
                text: .white,
                iconName: "checkmark",
                iconColor: .white
            )

        case .missed:
            return (
                bg: AnyShapeStyle(Color.clear),
                border: Color.red.opacity(0.75),
                text: .primary,
                iconName: "xmark",
                iconColor: Color.red.opacity(0.9)
            )

        case .none:
            if inCurrentMonth
            {
                return (
                    bg: AnyShapeStyle(Color.secondary.opacity(0.08)),
                    border: Color.secondary.opacity(0.15),
                    text: .primary,
                    iconName: nil,
                    iconColor: .clear
                )
            }
            else
            {
                return (
                    bg: AnyShapeStyle(Color.clear),
                    border: Color.clear,
                    text: Color.secondary.opacity(0.4),
                    iconName: nil,
                    iconColor: .clear
                )
            }
        }
    }

    // 8) Accesibilidad: texto con estado humano.
    private var accessibilityText: String
    {
        let df = DateFormatter()
        df.dateStyle = .full
        let base = df.string(from: date)

        switch status
        {
        case .success:
            return "\(base), goal met"
        case .missed:
            return "\(base), goal not met"
        case .none:
            return base
        }
    }
}

// =========================================================
// BLUR UIKit (NO SE USA EN ESTA VISTA ACTUAL)
// =========================================================
// 1) Bridge a UIKit.
// 2) Útil si quieres efectos específicos de blur.
// 3) Actualmente no está instanciado en CalendarView.
private struct VisualEffectBlur: UIViewRepresentable
{
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView
    {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// =========================================================
// PREVIEWS
// =========================================================
// 1) Crea una instancia de CalendarView con SampleData.
// 2) Inyecta modelContainer para que @Query funcione en preview.
#Preview("Dark")
{
    CalendarView(topic: SampleData.shared.topic)
        .modelContainer(SampleData.shared.modelContainer)
        .preferredColorScheme(.dark)
}

#Preview("Light")
{
    CalendarView(topic: SampleData.shared.topic)
        .modelContainer(SampleData.shared.modelContainer)
        .preferredColorScheme(.light)
}
